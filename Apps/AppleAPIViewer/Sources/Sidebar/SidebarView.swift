import AppleAPIViewerCore
import CoreModel
import IndexStore
import SwiftUI
import SymbolGraphIndex

private struct SidebarReloadKey: Hashable {
  let selections: [VersionSelection]
  let revision: Int
}

struct SidebarView: View {
  @Bindable var browser: BrowserModel
  @State private var frameworksByPlatform: [ApplePlatform: [FrameworkSummary]] =
    [:]
  @State private var collapsedSections: Set<ApplePlatform> = []
  @State private var isLoading = false

  var body: some View {
    Group {
      if browser.isComparing {
        CompareFrameworkList(browser: browser)
      } else {
        frameworkList
      }
    }
    .navigationTitle("Frameworks")
  }

  // MARK: - Private

  private var frameworkList: some View {
    List(selection: $browser.selectedFramework) {
      if browser.selectedPlatforms.isEmpty {
        ContentUnavailableView(
          "No platform selected",
          systemImage: "slider.horizontal.3",
          description: Text("Select an OS version in the filter above.")
        )
      } else {
        ForEach(browser.selectedPlatforms, id: \.self) { platform in
          Section(
            "\(platform.displayName) · \(browser.versionsLabel(for: platform))",
            isExpanded: expansionBinding(for: platform)
          ) {
            let frameworks = frameworksByPlatform[platform] ?? []
            if frameworks.isEmpty {
              Text(isLoading ? "Loading…" : "No new APIs")
                .font(.callout)
                .foregroundStyle(.secondary)
            } else {
              ForEach(frameworks) { framework in
                Label(framework.moduleName, systemImage: "shippingbox")
                  .badge(framework.newSymbolCount)
                  .tag(
                    FrameworkPick(
                      platform: platform, moduleName: framework.moduleName
                    )
                  )
              }
            }
          }
        }
      }
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      PlatformFilterPanel(browser: browser)
    }
    .task(
      id: SidebarReloadKey(
        selections: browser.selections, revision: browser.dataRevision
      )
    ) {
      await loadFrameworks()
    }
  }

  private func loadFrameworks() async {
    isLoading = true
    defer { isLoading = false }

    var result = frameworksByPlatform
    for platform in browser.selectedPlatforms {
      if let frameworks = await browser.frameworks(forPlatform: platform) {
        result[platform] = frameworks
      }
    }
    let selected = Set(browser.selectedPlatforms)
    result = result.filter { selected.contains($0.key) }
    frameworksByPlatform = result

    // A cleared platform filter removes the platform's entry entirely.
    // Without the empty-list fallback, the pick would survive and keep a
    // title and a re-index button for an unlisted framework.
    if let pick = browser.selectedFramework,
       !(result[pick.platform] ?? [])
       .contains(where: { $0.moduleName == pick.moduleName })
    {
      browser.selectedFramework = nil
    }
  }

  private func expansionBinding(for platform: ApplePlatform) -> Binding<Bool> {
    Binding(
      get: { !collapsedSections.contains(platform) },
      set: { isExpanded in
        if isExpanded {
          collapsedSections.remove(platform)
        } else {
          collapsedSections.insert(platform)
        }
      }
    )
  }
}
