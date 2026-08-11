import ArgumentParser
import CoreModel
import IndexOrchestration
import IndexStore
import SymbolGraphIndex

struct Diff: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "diff",
    abstract: "Show the API differences between two Xcodes' indexes."
  )

  // MARK: - Options

  @OptionGroup var options: GlobalOptions

  @Argument(
    help: "The framework name. Omit it to list every changed framework."
  )
  var module: String?

  @Option(
    name: .customLong("from"),
    help: "Build number of the Xcode index that is the old snapshot."
  )
  var fromBuild: String

  @Option(
    name: .customLong("to"),
    help:
    "Build number of the Xcode index that is the new snapshot. Defaults to the active Xcode."
  )
  var toBuild: String?

  // MARK: - Run

  func run() async throws {
    let built = try await options.openBuiltQuery(xcodeBuild: toBuild)
    let oldSource = Source.appleSDKID(forBuild: fromBuild)
    guard try await IndexStore().signature(forSource: oldSource) != nil else {
      throw fail(
        "No index for Xcode build \(fromBuild). Run 'apple-api-viewer-cli index status' to list the stored indexes.",
        code: ExitStatus.noIndex, name: "noIndex", format: options.format
      )
    }

    if let module {
      let resolved = try await resolveModule(
        module, query: built.query, oldSource: oldSource,
        newSource: built.source
      )
      let diff = try await built.query.frameworkDiff(
        forModule: resolved, from: oldSource, to: built.source
      )
      let output = FrameworkDiffOutput(diff)
      switch options.format {
      case .json:
        print(JSONLine.string(output))
      case .text:
        Self.printDiff(output)
      }
    } else {
      let summaries = try await built.query.frameworkDiffSummaries(
        from: oldSource, to: built.source
      )
      emit(summaries.map(DiffSummaryOutput.init), as: options.format) {
        "\($0.module)  +\($0.added) -\($0.removed) ~\($0.changed)"
      }
    }
  }

  // MARK: - Helpers

  // A framework can exist in only one of the two indexes, for example one
  // that the new SDK dropped. The module check spans both.
  private func resolveModule(
    _ module: String,
    query: SymbolQuery,
    oldSource: Source.ID,
    newSource: Source.ID
  ) async throws -> String {
    let names = Set(try await query.frameworkNames(source: newSource))
      .union(try await query.frameworkNames(source: oldSource))
    if names.contains(module) { return module }
    if let match = names.first(where: {
      $0.compare(module, options: .caseInsensitive) == .orderedSame
    }) {
      return match
    }
    throw fail(
      "No framework named '\(module)' in either index. Run 'apple-api-viewer-cli frameworks' to list the indexed frameworks.",
      code: ExitStatus.notFound, name: "notFound", format: options.format
    )
  }

  private static func printDiff(_ diff: FrameworkDiffOutput) {
    guard !diff.added.isEmpty || !diff.removed.isEmpty || !diff.changed.isEmpty
    else {
      print("No differences.")
      return
    }
    if !diff.added.isEmpty {
      print("Added (\(diff.added.count))")
      for symbol in diff.added { print("  \(symbol.kind)  \(symbol.title)") }
    }
    if !diff.removed.isEmpty {
      print("Removed (\(diff.removed.count))")
      for symbol in diff.removed { print("  \(symbol.kind)  \(symbol.title)") }
    }
    if !diff.changed.isEmpty {
      print("Changed (\(diff.changed.count))")
      for change in diff.changed {
        let reasons = change.reasons.joined(separator: ", ")
        print("  \(change.new.kind)  \(change.new.title)  (\(reasons))")
      }
    }
  }
}

// MARK: - Output types

struct DiffSummaryOutput: Encodable {
  let module: String
  let added: Int
  let removed: Int
  let changed: Int

  init(_ summary: FrameworkDiffSummary) {
    module = summary.moduleName
    added = summary.addedCount
    removed = summary.removedCount
    changed = summary.changedCount
  }
}

struct DiffSymbolOutput: Encodable {
  let usr: String
  let name: String
  let title: String
  let kind: String
  let path: [String]
  let deprecated: Bool
  let introduced: [String: String]

  init(_ symbol: IndexedSymbol) {
    usr = symbol.usr
    name = symbol.name
    title = symbol.title
    kind = symbol.kind.rawValue
    path = symbol.pathComponents
    deprecated = symbol.isDeprecated
    introduced = introducedReleases(symbol)
  }
}

struct SymbolChangeOutput: Encodable {
  let reasons: [String]
  let old: DiffSymbolOutput
  let new: DiffSymbolOutput

  init(_ change: SymbolChange) {
    reasons = change.reasons.map(\.rawValue).sorted()
    old = DiffSymbolOutput(change.old)
    new = DiffSymbolOutput(change.new)
  }
}

struct FrameworkDiffOutput: Encodable {
  let module: String
  let added: [DiffSymbolOutput]
  let removed: [DiffSymbolOutput]
  let changed: [SymbolChangeOutput]

  init(_ diff: FrameworkDiff) {
    module = diff.moduleName
    added = diff.added.map(DiffSymbolOutput.init)
    removed = diff.removed.map(DiffSymbolOutput.init)
    changed = diff.changed.map(SymbolChangeOutput.init)
  }
}
