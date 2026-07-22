import AppIntents
import AppleAPIViewerCore

struct SearchAPIsIntent: AppIntent {
  static let title: LocalizedStringResource = "Search APIs"
  static let description = IntentDescription(
    "Opens Apple API Viewer searching the index for a term."
  )
  static let openAppWhenRun = true

  @Parameter(title: "Term") var term: String

  @Dependency private var services: IntentServices

  static var parameterSummary: some ParameterSummary {
    Summary("Search APIs for \(\.$term)")
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    services.browser.searchText = term
    services.browser.searchPresented = true
    return .result()
  }
}
