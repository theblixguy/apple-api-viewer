import AppIntents
import AppleAPIViewerCore
import CoreModel

struct OpenFrameworkIntent: OpenIntent {
  static let title: LocalizedStringResource = "Open Framework"
  static let description = IntentDescription(
    "Opens Apple API Viewer showing a framework's new APIs."
  )

  @Parameter(title: "Framework") var target: FrameworkEntity

  @Dependency private var services: IntentServices

  @MainActor
  func perform() async throws -> some IntentResult {
    let browser = services.browser
    browser.searchPresented = false
    browser.searchText = ""
    browser.selectedSymbol = nil
    // A single-platform framework opened under another platform's scope
    // would show an empty tree, for example AppKit under iOS.
    var platform = browser.selectedPlatforms.first ?? .iOS
    for candidate in browser.selectedPlatforms {
      let frameworks = await browser.frameworks(forPlatform: candidate) ?? []
      if frameworks.contains(where: { $0.moduleName == target.id }) {
        platform = candidate
        break
      }
    }
    browser.selectedFramework = FrameworkPick(
      platform: platform, moduleName: target.id
    )
    return .result()
  }
}
