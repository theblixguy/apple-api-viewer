import ArgumentParser
import IndexOrchestration
import IndexStore
import SymbolGraphIndex

struct Search: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Search the index for symbols by name."
  )

  @OptionGroup var options: GlobalOptions
  @OptionGroup var indexSelection: IndexSelectionOptions

  @Argument(help: "The text to search for.")
  var term: String

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

  @Option(help: "Maximum number of hits.")
  var limit = IndexStore.defaultSearchLimit

  func validate() throws {
    guard limit >= 1 else {
      throw ValidationError("--limit must be at least 1.")
    }
  }

  func run() async throws {
    let built = try await options.openBuiltQuery(
      xcodeBuild: indexSelection.xcodeBuild
    )
    let hits = try await built.query.search(
      term,
      source: built.source,
      selections: releases.isEmpty ? nil : releases.map(\.selection),
      kinds: kinds.isEmpty ? nil : Set(kinds.map(\.kind)),
      limit: limit
    )
    let output = hits.map(SearchHitOutput.init)
    emit(output, as: options.format) { "\($0.kind)  \($0.module)  \($0.title)" }
  }
}

struct SearchHitOutput: Encodable {
  let usr: String
  let name: String
  let title: String
  let kind: String
  let module: String
  let path: [String]

  init(_ hit: SearchHit) {
    usr = hit.usr
    name = hit.name
    title = hit.title
    kind = hit.kind.rawValue
    module = hit.moduleName
    path = hit.pathComponents
  }
}
