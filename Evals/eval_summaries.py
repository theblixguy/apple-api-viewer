#!/usr/bin/env python3
"""Grades the on-device framework summaries produced by the production code.

Each case runs "apple-api-viewer-cli summarize <module> --select ... --eval", which
returns the summary together with the exact payload and limits the production
path used, then grades the summary with deterministic checks. The model is
stochastic, so every case runs several times and the report shows pass rates.
Re-run after changing the prompts or when a new OS model ships, and compare
reports.

Usage examples
  python3 Evals/eval_summaries.py --cli path/to/apple_api_viewer_cli
  python3 Evals/eval_summaries.py --cli ... --runs 5 --case WebKit:ios:26.5

TODO: Migrate to Xcode 27's Evaluations framework once GitHub adds a
macOS 27 runner.
"""

import argparse
import datetime
import json
import pathlib
import re
import subprocess
import sys

REPORTS_DIR = pathlib.Path(__file__).resolve().parent / "reports"

JUDGE_INSTRUCTIONS = """You grade one summary of the new APIs in an Apple \
framework release. The summary is for developers who browse what is new. \
Grade how well it reads, not whether it is complete.

Score 4: reads like a good release note, specific and fluent.
Score 3: mostly fluent, one vague or clumsy sentence.
Score 2: several vague, repetitive, or clumsy sentences.
Score 1: filler, lists disguised as prose, or text that explains nothing.

Reply with only this JSON and nothing else:
{"score": <1-4>, "rationale": "<one sentence>"}
"""

# Default cases spanning the three production paths and their boundaries.
# plain = deterministic digest (at most 4 symbols), model = one-shot (payload
# within the 8000 byte budget), chunked = split and merged. TouchController
# and SwiftUICore sit near the budget boundary, and the harness reads the
# mode each run reports rather than assuming one. Frameworks and releases
# must exist in the local index.
DEFAULT_CASES = [
    "DeclaredAgeRange:ios:26.0",
    "StoreKit:ios:26.5",
    "WebKit:ios:26.5",
    "AccessoryLiveActivities:ios:26.5",
    "PencilKit:ios:26.0",
    "TouchController:ios:26.0",
    "SwiftUICore:ios:26.0",
    "SwiftUI:macos:26.0",
]

BOILERPLATE = [
    r"enhanc\w* the (ability|framework|capabilit)",
    r"allowing developers",
    r"empower\w*",
    r"seamless",
    r"comprehensive",
    r"leverag\w*",
    r"robust",
    r"streamlin\w*",
    r"in (contexts|scenarios) where",
]

KIND_JARGON = ["enumCase", "typeAlias", "typeProperty", "typeMethod"]

# Words that look like symbols but are ordinary prose, lowercased for lookup.
PROSE_ALLOWLIST = {
    "apple",
    "api",
    "apis",
    "the",
    "new",
    "framework",
    "ios",
    "macos",
    "watchos",
    "tvos",
    "visionos",
    "swift",
    "it",
    "these",
    "this",
    "an",
    "a",
    "ids",
    "uis",
    "sdk",
    "sdks",
    "os",
}


def judge(judge_cli, record):
    prompt = (
        f"{JUDGE_INSTRUCTIONS}\n"
        f"Framework: {record['module']}\n"
        f"Requested sentence limit: {record['sentenceLimit']}\n"
        f"Summary:\n{record['summary']}"
    )
    try:
        result = subprocess.run(
            [judge_cli, "-p", prompt],
            capture_output=True,
            text=True,
            timeout=240,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        return None, str(error)
    if result.returncode != 0:
        return None, f"exit {result.returncode}: {result.stderr.strip()[:200]}"
    match = re.search(r"\{.*\}", result.stdout, re.DOTALL)
    if not match:
        return None, f"no JSON in judge reply: {result.stdout.strip()[:200]}"
    try:
        verdict = json.loads(match.group(0))
        score = int(verdict["score"])
    except (json.JSONDecodeError, KeyError, TypeError, ValueError):
        return None, f"bad judge JSON: {match.group(0)[:200]}"
    if not 1 <= score <= 4:
        return None, f"judge score out of range: {score}"
    return {"score": score, "rationale": str(verdict.get("rationale", ""))}, None


def write_report(report):
    REPORTS_DIR.mkdir(exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y-%m-%d at %H.%M.%S")
    path = REPORTS_DIR / f"{stamp}.json"
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    return path


def load_baseline(argument):
    if argument == "latest":
        candidates = sorted(REPORTS_DIR.glob("*.json"))
        if not candidates:
            return None, "no reports in Evals/reports yet"
        return json.loads(candidates[-1].read_text()), None
    path = pathlib.Path(argument)
    if not path.exists():
        return None, f"no baseline at {path}"
    return json.loads(path.read_text()), None


def compare_to_baseline(baseline, current):
    regressions = []
    print(f"\n=== versus baseline {baseline['created']} ===")
    for case, now in current["cases"].items():
        then = baseline["cases"].get(case)
        if then is None:
            print(f"  {case}: new case, no baseline")
            continue
        for name, (passed, total) in sorted(now["checks"].items()):
            was = then["checks"].get(name)
            if was is None or total == 0 or was[1] == 0:
                continue
            rate, base_rate = passed / total, was[0] / was[1]
            if rate < base_rate:
                regressions.append(f"{case} {name}")
                print(
                    f"  {case} {name}: REGRESSED "
                    f"{was[0]}/{was[1]} to {passed}/{total}"
                )
            elif rate > base_rate:
                print(
                    f"  {case} {name}: improved "
                    f"{was[0]}/{was[1]} to {passed}/{total}"
                )
        scores, base_scores = now.get("judgeScores"), then.get("judgeScores")
        if scores and base_scores:
            mean = sum(scores) / len(scores)
            base_mean = sum(base_scores) / len(base_scores)
            if mean < base_mean - 0.5:
                regressions.append(f"{case} judge")
                print(f"  {case} judge: REGRESSED {base_mean:.1f} to {mean:.1f}")
    if not regressions:
        print("  no regressions")
    return regressions


def run_case(cli, case, xcode):
    module, *select = case.split(":")
    selection = ":".join(select)
    command = [cli, "summarize", module, "--select", selection, "--eval"]
    if xcode:
        command += ["--xcode", xcode]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        return None, f"exit {result.returncode}: {result.stderr.strip()[:200]}"
    return json.loads(result.stdout), None


def sentences(text):
    parts = re.split(r"(?<=[.!?])\s+", text.strip())
    return [p for p in parts if p]


def symbol_tokens(text):
    # Tokens that claim to be API names, an internal capital after a lowercase
    # letter or a dotted path. Plain capitalized words are ordinary prose.
    # The segment class excludes the dot, so dots only separate segments.
    # With a dot in the class, a run of dots would backtrack exponentially.
    candidates = re.findall(r"\b[A-Z][A-Za-z0-9]*(?:\.[A-Za-z0-9_():]+)*\b", text)
    return {
        t
        for t in candidates
        if re.search(r"[a-z][A-Z]|\.", t) or re.match(r"^[A-Z]{2,}[a-z]", t)
    }


def grade(record):
    summary = record["summary"]
    payload = record["payload"]
    checks = {}

    checks["prose_format"] = not (
        "**" in summary
        or "###" in summary
        or re.search(r"\*[^*\n]+\*", summary)
        or re.search(r"^\s*[-•*]\s", summary, re.MULTILINE)
        or re.search(r"^\s*\d+\.\s", summary, re.MULTILINE)
    )

    limit = record["sentenceLimit"]
    count = len(sentences(summary))
    checks["sentence_cap"] = count <= limit + 1

    checks["no_kind_jargon"] = not any(j in summary for j in KIND_JARGON)

    checks["no_boilerplate"] = not any(
        re.search(pattern, summary, re.IGNORECASE) for pattern in BOILERPLATE
    )

    if record["mode"] == "plain":
        checks["plain_is_deterministic"] = summary.startswith(
            f"{record['module']} adds "
        )
    else:
        # Every API-shaped token must exist in the payload, or the model
        # invented a symbol.
        haystack = payload + " " + record["module"]
        invented = [
            token
            for token in symbol_tokens(summary)
            if token.lower() not in PROSE_ALLOWLIST
            and token.split(".")[-1].rstrip("s") not in haystack
            and token.split(".")[-1] not in haystack
        ]
        checks["grounded_symbols"] = not invented
        if invented:
            checks["_invented"] = invented

        # A digest that names no symbol at all summarized nothing.
        checks["mentions_a_symbol"] = any(
            token.split(".")[-1] in payload
            for token in symbol_tokens(summary)
            if token.lower() not in PROSE_ALLOWLIST
        )

    return checks, count


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cli", required=True, help="Path to apple_api_viewer_cli")
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--xcode", help="Index to read, as an Xcode build number")
    parser.add_argument(
        "--case",
        action="append",
        dest="cases",
        help="module:platform:version, repeatable. Defaults to a size spread.",
    )
    parser.add_argument(
        "--baseline",
        help='A report to compare against, a path or "latest". '
        "A drop in any pass rate fails the run.",
    )
    parser.add_argument(
        "--judge",
        help="Grade each model summary 1 to 4 with this CLI. The command "
        "must accept -p <prompt> and print the reply.",
    )
    args = parser.parse_args()
    cases = args.cases or DEFAULT_CASES

    baseline = None
    if args.baseline:
        baseline, error = load_baseline(args.baseline)
        if baseline is None:
            print(f"baseline unavailable: {error}")
            return 1

    report = {
        "created": datetime.datetime.now(datetime.timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        ),
        "runs": args.runs,
        "cases": {},
    }

    failures = 0
    graded_runs = 0
    skipped_cases = []
    for case in cases:
        print(f"\n=== {case} ===")
        totals = {}
        judge_scores = []
        first_summary = None
        for run in range(args.runs):
            record, error = run_case(args.cli, case, args.xcode)
            if record is None:
                print(f"  run {run + 1}: SKIP ({error})")
                continue
            graded_runs += 1
            if first_summary is None:
                first_summary = record["summary"]
            checks, count = grade(record)
            invented = checks.pop("_invented", None)
            for name, passed in checks.items():
                done, total = totals.get(name, (0, 0))
                totals[name] = (done + (1 if passed else 0), total + 1)
            failed = [name for name, passed in checks.items() if not passed]
            status = "PASS" if not failed else f"FAIL {failed}"
            if failed:
                failures += 1
            print(
                f"  run {run + 1}: {status}  "
                f"[{record['mode']}, {record['matchCount']} symbols, "
                f"{count}/{record['sentenceLimit']} sentences]"
            )
            if invented:
                print(f"    invented symbols: {invented}")
            if run == 0 or failed:
                for line in record["summary"].splitlines():
                    print(f"    | {line}")
            if args.judge and record["mode"] != "plain":
                verdict, error = judge(args.judge, record)
                if verdict is None:
                    print(f"    judge: SKIP ({error})")
                else:
                    judge_scores.append(verdict["score"])
                    print(
                        f"    judge: {verdict['score']}/4 {verdict['rationale']}"
                    )
            if record["mode"] == "plain":
                break
        # A case with no graded run has no checks. In a report it would
        # neutralize a later baseline comparison, and an ALL PASS over it
        # would be a false green.
        if not totals:
            skipped_cases.append(case)
            continue
        entry = {"checks": totals}
        if judge_scores:
            entry["judgeScores"] = judge_scores
        if first_summary is not None:
            entry["firstSummary"] = first_summary
        report["cases"][case] = entry

    if graded_runs == 0:
        print("\nno summaries were graded, so there is no verdict")
        print("check the index and Apple Intelligence, then run again")
        return 1

    regressions = []
    if baseline:
        regressions = compare_to_baseline(baseline, report)

    report_path = write_report(report)
    print(f"\nreport: {report_path}")
    problems = []
    if failures:
        problems.append(f"FAILURES: {failures}")
    if skipped_cases:
        problems.append(f"SKIPPED CASES: {len(skipped_cases)}")
    if regressions:
        problems.append(f"REGRESSIONS: {len(regressions)}")
    print("  ".join(problems) if problems else "ALL PASS")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
