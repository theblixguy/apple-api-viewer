import Foundation

/// Converts the DocC flavored markdown in SDK doc comments into plain
/// CommonMark a general markdown renderer can display.
///
/// SDK doc comments arrive verbatim from the symbol graph and can contain
/// DocC block directives such as `@TabNavigator`, `@Tab`, and
/// `@DeprecationSummary`. This type rewrites those directives into plain
/// markdown.
public nonisolated enum DocCommentMarkdown {
  /// Returns `summary` with its DocC block directives rewritten into plain
  /// markdown. The method unwraps containers, labels tabs and deprecation
  /// notes, and drops directives with nothing to render. Fenced code
  /// passes through unchanged.
  ///
  /// - Parameter summary: The DocC flavored markdown to rewrite.
  /// - Returns: The plain CommonMark markdown.
  public static func plainMarkdown(from summary: String) -> String {
    var lines: [String] = []
    var openDirectives: [String] = []
    var suppressionDepth = 0
    var inFence = false

    for line in summary.split(separator: "\n", omittingEmptySubsequences: false)
    {
      let trimmed = line.trimmingCharacters(in: .whitespaces)

      if trimmed.hasPrefix("```") {
        inFence.toggle()
        if suppressionDepth == 0 { lines.append(String(line)) }
        continue
      }
      if inFence {
        if suppressionDepth == 0 { lines.append(String(line)) }
        continue
      }

      if let directive = blockDirectiveName(in: trimmed) {
        openDirectives.append(directive)
        if directive == "Comment" {
          suppressionDepth += 1
        } else if suppressionDepth == 0 {
          if directive == "Tab", let title = quotedArgument(in: trimmed) {
            lines.append("**\(title)**")
            lines.append("")
          } else if directive == "DeprecationSummary" {
            lines.append("**Deprecated**")
            lines.append("")
          }
        }
        continue
      }

      if trimmed == "}", !openDirectives.isEmpty {
        if openDirectives.removeLast() == "Comment" {
          suppressionDepth -= 1
        }
        continue
      }

      if isSingleLineDirective(trimmed) { continue }

      if suppressionDepth == 0 { lines.append(String(line)) }
    }

    return lines.joined(separator: "\n")
  }

  private static func blockDirectiveName(in line: String) -> String? {
    let pattern = /@([A-Za-z][A-Za-z0-9]*)(?:\([^)]*\))?\s*\{/
    guard let match = line.wholeMatch(of: pattern) else { return nil }
    return String(match.1)
  }

  // A bare `@Word` line is not a directive. Prose can legitimately start
  // with an attribute name.
  private static func isSingleLineDirective(_ line: String) -> Bool {
    line.wholeMatch(of: /@[A-Za-z][A-Za-z0-9]*\([^)]*\)/) != nil
  }

  private static func quotedArgument(in line: String) -> String? {
    guard let match = line.firstMatch(of: /"([^"]*)"/) else { return nil }
    return String(match.1)
  }
}
