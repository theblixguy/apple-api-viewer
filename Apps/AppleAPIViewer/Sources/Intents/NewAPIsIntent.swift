import AppIntents
import AppleAPIViewerCore
import CoreModel
import SymbolGraphIndex

struct NewAPIsIntent: AppIntent {
  static let title: LocalizedStringResource = "Get New APIs"
  static let description = IntentDescription(
    "Lists a framework's new APIs as Markdown, filtered to an OS release."
  )

  @Parameter(title: "Framework") var framework: FrameworkEntity
  @Parameter(title: "Release") var release: ReleaseEntity?

  @Dependency private var services: IntentServices

  static var parameterSummary: some ParameterSummary {
    Summary("Get new APIs in \(\.$framework) for \(\.$release)")
  }

  @MainActor
  func perform() async throws
    -> some IntentResult & ReturnsValue<String> & ProvidesDialog
  {
    guard let source = await services.resolveSource() else {
      throw IntentError.noIndex
    }
    let selections: [VersionSelection] = if let release {
      [release.selection]
    } else {
      try await services.newestReleases(source: source)
    }
    let tree = try await services.query.newSymbolTree(
      forModule: framework.id, source: source, selections: selections
    )
    guard !tree.isEmpty else {
      let releasesLabel = NewAPIExport.releasesLabel(for: selections)
      let releases =
        releasesLabel.hasPrefix("New in ")
          ? String(releasesLabel.dropFirst("New in ".count)) : releasesLabel
      return .result(
        value: "",
        dialog: "No new APIs in \(framework.id) for \(releases)."
      )
    }
    let markdown = NewAPIExport.markdown(
      module: framework.id, selections: selections, tree: tree
    )
    let count = NewAPIExport.matchCount(in: tree)
    return .result(
      value: markdown,
      dialog: "^[\(count) new APIs](inflect: true) in \(framework.id)."
    )
  }
}
