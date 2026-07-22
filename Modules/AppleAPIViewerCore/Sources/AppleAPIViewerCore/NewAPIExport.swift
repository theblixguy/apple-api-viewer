import CoreModel
import DocURLMapping
import Foundation
import SymbolGraphIndex

/// Renders a framework's new-symbol tree as text for sharing and for the
/// on-device language model.
///
/// Everything here is a pure function over the tree. The type is
/// nonisolated and callable from the summarizer's concurrent pipeline.
public nonisolated enum NewAPIExport {
  /// Returns a Markdown document listing a framework's new APIs for the
  /// given releases, with documentation links on every new symbol.
  ///
  /// - Parameters:
  ///   - module: The framework name.
  ///   - selections: The active version selections the releases label
  ///     describes.
  ///   - tree: The framework's new-symbol tree to render.
  /// - Returns: The Markdown document.
  public static func markdown(
    module: String,
    selections: [VersionSelection],
    tree: [SymbolTreeNode]
  ) -> String {
    var lines = ["# What's new in \(module)"]
    let releases = releasesLabel(for: selections)
    if !releases.isEmpty {
      lines.append("")
      lines.append(releases)
    }
    lines.append("")
    for node in tree {
      appendMarkdown(node, module: module, depth: 0, into: &lines)
    }
    return lines.joined(separator: "\n")
  }

  /// Returns the compact one-symbol-per-line form fed to the language
  /// model, small enough that a large framework fits its context window.
  ///
  /// - Parameter tree: The framework's new-symbol tree to render.
  /// - Returns: The compact one-symbol-per-line form of the tree.
  public static func modelLines(tree: [SymbolTreeNode]) -> String {
    var lines: [String] = []
    appendModelLines(tree, into: &lines)
    return lines.joined(separator: "\n")
  }

  /// Returns ``modelLines(tree:)`` split per top-level subtree. Each chunk
  /// fits the model's context window.
  ///
  /// - Parameter tree: The framework's new-symbol tree to render.
  /// - Returns: The rendered chunks, one per top-level subtree.
  public static func modelLineChunks(tree: [SymbolTreeNode]) -> [String] {
    tree.map { node in
      var lines: [String] = []
      appendModelLines([node], into: &lines)
      return lines.joined(separator: "\n")
    }
  }

  /// Returns the count of new symbols in the tree, excluding context-only
  /// parents.
  ///
  /// - Parameter tree: The framework's new-symbol tree to count.
  /// - Returns: The count of new symbols.
  public static func matchCount(in tree: [SymbolTreeNode]) -> Int {
    tree.reduce(0) { total, node in
      total + (node.isMatch ? 1 : 0) + matchCount(in: node.children)
    }
  }

  /// Returns a one-sentence digest for a small delta. The method builds
  /// it without the language model.
  ///
  /// - Parameters:
  ///   - module: The framework name.
  ///   - tree: The framework's new-symbol tree to digest.
  /// - Returns: The one-sentence digest.
  public static func plainDigest(module: String, tree: [SymbolTreeNode])
    -> String
  {
    let all = matches(in: tree)
    let notable = all.filter { !isNoise($0) }
    let items = (notable.isEmpty ? all : notable).map {
      "the \($0.title) \(SymbolDisplay.label(for: $0.kind).lowercased())"
    }
    guard !items.isEmpty else { return "" }
    return String(
      localized: "\(module) adds \(items.formatted(.list(type: .and)))."
    )
  }

  private static func matches(in tree: [SymbolTreeNode]) -> [IndexedSymbol] {
    tree.flatMap { node in
      (node.isMatch ? [node.symbol] : []) + matches(in: node.children)
    }
  }

  /// Returns a short label naming the selected releases, for example
  /// "New in iOS 26.0 and macOS 26.0".
  ///
  /// - Parameter selections: The active version selections to name.
  /// - Returns: The short label naming the selections.
  public static func releasesLabel(for selections: [VersionSelection]) -> String
  {
    let names = selections.map {
      "\($0.platform.displayName) \(BrowserModel.versionLabel($0.version))"
    }
    guard !names.isEmpty else { return "" }
    return String(
      localized: "New in \(names.formatted(.list(type: .and)))"
    )
  }

  // MARK: - Private

  private static func appendMarkdown(
    _ node: SymbolTreeNode, module: String, depth: Int,
    into lines: inout [String]
  ) {
    let indent = String(repeating: "  ", count: depth)
    let kind = SymbolDisplay.label(for: node.symbol.kind)
    let title = markdownEscaped(node.symbol.title)
    if node.isMatch {
      let url = DocumentationURLMapper.documentationURL(
        framework: module, pathComponents: node.symbol.pathComponents
      )
      var line = "\(indent)- [\(title)](\(url.absoluteString)) (\(kind))"
      let releases = introducedLabel(for: node.symbol)
      if !releases.isEmpty {
        line += ", new in \(releases)"
      }
      lines.append(line)
    } else {
      lines.append("\(indent)- \(title) (\(kind))")
    }
    for child in node.children {
      appendMarkdown(child, module: module, depth: depth + 1, into: &lines)
    }
  }

  // CommonMark treats these characters as markup inside inline text.
  // Without escapes, a title like `init(_:_:)` renders with the
  // underscores parsed as emphasis.
  private static func markdownEscaped(_ text: String) -> String {
    var escaped = ""
    escaped.reserveCapacity(text.count)
    for character in text {
      if "\\`*_[]<>".contains(character) {
        escaped.append("\\")
      }
      escaped.append(character)
    }
    return escaped
  }

  private static func introducedLabel(for symbol: IndexedSymbol) -> String {
    symbol.introduced
      .filter { !$0.value.isUnversioned }
      .sorted { $0.key.rawValue < $1.key.rawValue }
      .map { "\($0.key.displayName) \($0.value)" }
      .joined(separator: ", ")
  }

  // Protocol-conformance boilerplate adds no information beyond the
  // conformance itself. Digests exclude it.
  private static let conformanceNoise: Set<String> = [
    "==(_:_:)", "!=(_:_:)", "hash(into:)", "hashValue", "allCases", "AllCases",
    "description", "debugDescription", "rawValue", "init(rawValue:)",
    "encode(to:)", "init(from:)", "CodingKeys",
  ]

  private static func isNoise(_ symbol: IndexedSymbol) -> Bool {
    conformanceNoise.contains(symbol.name)
  }

  // Digests name types. An abstract on every member would exceed the
  // model's context budget.
  private static let documentedKinds: Set<SymbolKind> = [
    .class, .structure, .enumeration, .protocol,
  ]

  // One clause grounds the model without spending the byte budget on a full
  // discussion.
  private static let abstractLimit = 160

  private static func appendModelLines(
    _ nodes: [SymbolTreeNode], into lines: inout [String]
  ) {
    for node in nodes {
      if !isNoise(node.symbol) {
        var line =
          "\(SymbolDisplay.label(for: node.symbol.kind)) \(node.symbol.title)"
        if documentedKinds.contains(node.symbol.kind),
           let abstract = clippedAbstract(of: node.symbol)
        {
          line += ": \(abstract)"
        }
        lines.append(line)
      }
      appendModelLines(node.children, into: &lines)
    }
  }

  private static func clippedAbstract(of symbol: IndexedSymbol) -> String? {
    guard let summary = symbol.summary else { return nil }
    var text = summary.replacingOccurrences(of: "\n", with: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return nil }
    if let boundary = text.firstMatch(of: /[.!?](?=\s)/) {
      text = String(text[..<boundary.range.upperBound])
    }
    return String(text.prefix(abstractLimit))
  }
}
