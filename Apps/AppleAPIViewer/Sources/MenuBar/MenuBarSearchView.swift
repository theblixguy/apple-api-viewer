import AppleAPIViewerCore
import IndexOrchestration
import IndexStore
import SwiftUI
import SymbolGraphIndex

struct MenuBarSearchView: View {
  let coordinator: IndexCoordinator
  let browser: BrowserModel

  @State private var searchText = ""
  @State private var hits: [SearchHit] = []
  @Environment(\.openWindow) private var openWindow
  @Environment(\.dismiss) private var dismiss

  private var query: SymbolQuery {
    SymbolQuery(store: browser.store)
  }

  private var filterSummary: String {
    let parts = browser.selectedPlatforms.map {
      "\($0.displayName) \(browser.selectionLabel(for: $0))"
    }
    return parts.isEmpty
      ? String(localized: "All releases") : parts.joined(separator: ", ")
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: Spacing.xSmall) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        TextField("Search APIs", text: $searchText)
          .textFieldStyle(.plain)
          .onSubmit(openInApp)
      }
      .padding(.horizontal, Spacing.small)
      .padding(.vertical, Spacing.xSmall + 2)
      .background(
        .quaternary.opacity(0.6),
        in: RoundedRectangle(cornerRadius: CornerRadius.inset)
      )
      .padding(Spacing.small)

      HStack {
        Menu {
          PlatformFilterMenuContent(browser: browser)
        } label: {
          Label(
            filterSummary,
            systemImage: "line.3.horizontal.decrease.circle"
          )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Filter results by OS release")
        Spacer()
      }
      .font(.caption)
      .padding(.horizontal, Spacing.small)
      .padding(.bottom, Spacing.small)

      Divider()

      if hits.isEmpty {
        Text(
          searchText.count >= BrowserModel.minimumSearchLength
            ? "No results." : "Search new APIs in the selected releases."
        )
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: Metrics.menuBarEmptyHeight)
      } else {
        ScrollView {
          LazyVStack(spacing: Spacing.xxSmall) {
            ForEach(hits) { hit in
              Button {
                open(hit)
              } label: {
                HStack(spacing: Spacing.small) {
                  Image(
                    systemName: SymbolDisplay.systemImageName(for: hit.kind)
                  )
                  .foregroundStyle(.tint)
                  .accessibilityHidden(true)
                  VStack(alignment: .leading, spacing: 1) {
                    Text(hit.title)
                      .lineLimit(1)
                      .truncationMode(.middle)
                    Text(hit.moduleName)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
              }
            }
          }
          .buttonStyle(MenuRowButtonStyle())
          .padding(Spacing.xSmall)
        }
        .frame(height: Metrics.menuBarListHeight)
      }

      Divider()

      VStack(spacing: Spacing.xxSmall) {
        Button("Open Apple API Viewer") { activateMainWindow() }
        Button("Quit Apple API Viewer") { NSApp.terminate(nil) }
      }
      .buttonStyle(MenuRowButtonStyle())
      .padding(Spacing.xSmall)
    }
    .frame(width: Metrics.menuBarWidth)
    .task {
      if browser.releasesByPlatform.isEmpty {
        await browser.loadPickerData()
      }
    }
    .task(id: QueryInputs(text: searchText, selections: browser.selections)) {
      let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
      guard trimmed.count >= BrowserModel.minimumSearchLength else {
        hits = []
        return
      }
      try? await Task.sleep(for: .milliseconds(200))
      guard !Task.isCancelled, let source = coordinator.activeSourceID else {
        return
      }
      let selections = browser.selections
      let results = try? await query.search(
        trimmed, source: source,
        selections: selections.isEmpty ? nil : selections,
        limit: Metrics.menuBarResultLimit
      )
      guard !Task.isCancelled, let results else { return }
      hits = results
    }
  }

  // MARK: - Private

  private struct QueryInputs: Hashable {
    let text: String
    let selections: [VersionSelection]
  }

  // MARK: - Actions

  private func open(_ hit: SearchHit) {
    browser.searchPresented = false
    browser.searchText = ""
    browser.selectedSymbol = SymbolReference(
      usr: hit.usr, moduleName: hit.moduleName
    )
    activateMainWindow()
  }

  private func openInApp() {
    browser.searchText = searchText
    browser.searchPresented = true
    activateMainWindow()
  }

  private func activateMainWindow() {
    // A valueless WindowGroup makes a new window on every openWindow
    // call. SwiftUI names the group's windows "<id>-AppWindow-<n>".
    let existing = NSApp.windows.first {
      guard let identifier = $0.identifier?.rawValue else { return false }
      return identifier == WindowID.main
        || identifier.hasPrefix("\(WindowID.main)-")
    }
    if let existing {
      if existing.isMiniaturized { existing.deminiaturize(nil) }
      existing.makeKeyAndOrderFront(nil)
    } else {
      openWindow(id: WindowID.main)
    }
    NSApp.activate()
    dismiss()
  }
}
