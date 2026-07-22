import ArgumentParser
import CoreModel
import SymbolGraphIndex

enum OutputFormat: String, ExpressibleByArgument, Sendable {
  case text
  case json
}

struct GlobalOptions: ParsableArguments {
  @Option(help: "Output format, text or json.")
  var format: OutputFormat = .text

  @Flag(name: .shortAndLong, help: "Print only the final result, no progress.")
  var quiet = false

  @Option(
    name: .customLong("db"),
    help: "Path to the index database. Defaults to the app's shared index."
  )
  var databasePath: String?
}

struct IndexSelectionOptions: ParsableArguments {
  @Option(
    name: .customLong("xcode"),
    help:
    "Build number of the Xcode index to query, including one whose Xcode is gone. Defaults to the active Xcode."
  )
  var xcodeBuild: String?
}

struct ReleaseFilter: ExpressibleByArgument, Sendable {
  let selection: VersionSelection

  init?(argument: String) {
    let parts = argument.split(separator: ":", maxSplits: 1)
    guard parts.count == 2,
          let platform = ApplePlatform.allCases.first(where: {
            $0.rawValue.lowercased() == parts[0].lowercased()
          }),
          let version = SemanticVersion(String(parts[1]))
    else { return nil }
    selection = VersionSelection(platform: platform, version: version)
  }
}

extension [ReleaseFilter] {
  func requireSelections() throws -> [VersionSelection] {
    guard !isEmpty else {
      throw ValidationError(
        "Add at least one release with --select platform:version."
      )
    }
    return map(\.selection)
  }
}

struct KindFilter: ExpressibleByArgument, Sendable {
  let kind: SymbolKind

  init?(argument: String) {
    guard let kind = SymbolKind(rawValue: argument) else { return nil }
    self.kind = kind
  }
}
