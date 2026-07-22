# Summarizer evals

Quality checks for the on-device framework summaries. Each case runs through `apple-api-viewer-cli summarize --eval`, so the grades measure the same prompts, payloads, and chunk splits as production.

## Run

Build the CLI, then run the harness:

```sh
python3 Evals/eval_summaries.py \
  --cli ~/Library/Developer/Xcode/DerivedData/AppleAPIViewer-*/Build/Products/Debug/apple_api_viewer_cli
```

The model does not give the same output each time, so compare pass rates across runs, not single outputs. `--runs 5` samples each case five times. `--case Module:platform:version` adds or replaces cases. `--xcode <build>` selects a stored index.

## Checks

- `prose_format` fails when the summary contains bullet lists, bold text, or headings.
- `sentence_cap` fails when the summary exceeds the requested limit plus one.
- `grounded_symbols` fails when the summary names an API that is not in the payload.
- `mentions_a_symbol` fails when a digest names no symbol at all.
- `no_kind_jargon` fails when a payload token such as `enumCase` leaks into the summary.
- `no_boilerplate` fails when the summary contains filler such as "allowing developers".
- `plain_is_deterministic` fails when the small-delta path, which skips the model, does not produce its fixed sentence.

## Judge

`--judge <command>` grades each model summary from 1 to 4 on how well it reads. Any command that accepts `-p <prompt>` and prints the reply can be the judge. Pick a model that is stronger than the on-device model, so the grades come from an independent reader.

## Reports and baselines

Every run writes a JSON report to `Evals/reports/`. `--baseline latest` or `--baseline <path>` compares the run against a stored report and fails when quality drops.

## When to run

- After you change the prompts, sentence targets, or payload format.
- After a macOS update ships a new on-device model.

When GitHub adds a macOS 27 runner, this harness will migrate to Xcode 27's Evaluations framework.
