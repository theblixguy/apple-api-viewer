import ArgumentParser
import IndexOrchestration
import SymbolGraphIndex

struct New: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "new",
    abstract: "Show the tree of new symbols in a framework."
  )

  // MARK: - Options

  @OptionGroup var options: GlobalOptions
  @OptionGroup var indexSelection: IndexSelectionOptions

  @Argument(help: "The framework name.")
  var module: String

  @Option(
    name: .customLong("select"),
    help: "An OS release as platform:version like ios:26.0. Repeatable."
  )
  var releases: [ReleaseFilter] = []

  @Option(
    name: .customLong("kind"),
    help: "Limit matches to a symbol kind. Repeatable."
  )
  var kinds: [KindFilter] = []

  // MARK: - Run

  func run() async throws {
    let selections = try releases.requireSelections()
    let built = try await options.openBuiltQuery(
      xcodeBuild: indexSelection.xcodeBuild
    )
    let module = try await built.requireModule(module, format: options.format)
    let tree = try await built.query.newSymbolTree(
      forModule: module, source: built.source,
      selections: selections,
      kinds: kinds.isEmpty ? nil : Set(kinds.map(\.kind))
    )
    let output = tree.map(SymbolNodeOutput.init)
    switch options.format {
    case .json:
      print(JSONLine.string(output))
    case .text:
      if output.isEmpty {
        print("No results.")
      } else {
        for node in output { Self.printNode(node, depth: 0) }
      }
    }
  }

  // MARK: - Helpers

  private static func printNode(_ node: SymbolNodeOutput, depth: Int) {
    let indent = String(repeating: "  ", count: depth)
    let badge = node.match ? "" : " (parent)"
    print("\(indent)\(node.kind)  \(node.name)\(badge)")
    for child in node.children { printNode(child, depth: depth + 1) }
  }
}

// MARK: - Output types

struct SymbolNodeOutput: Encodable {
  let usr: String
  let name: String
  let title: String
  let kind: String
  let match: Bool
  let path: [String]
  let introduced: [String: String]
  let children: [SymbolNodeOutput]

  init(_ node: SymbolTreeNode) {
    usr = node.symbol.usr
    name = node.symbol.name
    title = node.symbol.title
    kind = node.symbol.kind.rawValue
    match = node.isMatch
    path = node.symbol.pathComponents
    introduced = introducedReleases(node.symbol)
    children = node.children.map(SymbolNodeOutput.init)
  }
}
