import AppleAPIViewerCore
import ArgumentParser
import IndexOrchestration
import SymbolGraphIndex

struct Summarize: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Summarize a framework's new APIs with the on-device model."
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

  @Flag(
    name: .customLong("eval"),
    help:
    "Emit an evaluation record with the summary, payload, and limits as JSON."
  )
  var eval = false

  // MARK: - Run

  func run() async throws {
    let selections = try releases.requireSelections()
    let built = try await options.openBuiltQuery(
      xcodeBuild: indexSelection.xcodeBuild
    )
    let module = try await built.requireModule(module, format: options.format)
    let tree = try await built.query.newSymbolTree(
      forModule: module, source: built.source, selections: selections
    )
    guard !tree.isEmpty else {
      throw fail(
        "No new APIs in \(module) for the selected releases.",
        code: ExitStatus.notFound, name: "notFound", format: options.format
      )
    }
    let matchCount = NewAPIExport.matchCount(in: tree)
    let usesModel = matchCount > FrameworkSummarizer.smallDeltaLimit
    if usesModel {
      guard FrameworkSummarizer.isAvailable else {
        throw fail(
          "The on-device model isn't available. Turn on Apple Intelligence in System Settings to summarize.",
          code: ExitStatus.modelUnavailable, name: "modelUnavailable",
          format: options.format
        )
      }
    }
    let releasesLabel = NewAPIExport.releasesLabel(for: selections)
    let summary = try await FrameworkSummarizer.summarize(
      module: module, releasesLabel: releasesLabel, tree: tree
    )
    if eval {
      let payload = NewAPIExport.modelLines(tree: tree)
      let record = SummaryEvalRecord(
        module: module,
        matchCount: matchCount,
        mode: Self.mode(usesModel: usesModel, payload: payload),
        sentenceLimit: FrameworkSummarizer.sentenceTarget(for: matchCount),
        payload: payload,
        summary: summary
      )
      print(JSONLine.string(record))
    } else {
      emitOne(
        SummaryOutput(module: module, summary: summary), as: options.format
      ) {
        summary
      }
    }
  }

  // MARK: - Helpers

  private static func mode(usesModel: Bool, payload: String) -> String {
    guard usesModel else { return "plain" }
    return payload.utf8.count > FrameworkSummarizer.payloadByteBudget
      ? "chunked" : "model"
  }
}

// MARK: - Output types

struct SummaryOutput: Encodable {
  let module: String
  let summary: String
}

struct SummaryEvalRecord: Encodable {
  let module: String
  let matchCount: Int
  let mode: String
  let sentenceLimit: Int
  let payload: String
  let summary: String
}
