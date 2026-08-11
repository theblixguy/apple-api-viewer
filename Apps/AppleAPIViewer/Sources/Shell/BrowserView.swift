import AppleAPIViewerCore
import IndexStore
import SwiftUI

struct BrowserView: View {
  @Bindable var browser: BrowserModel
  let coordinator: IndexCoordinator
  @State private var storageWarningDismissed = false

  var body: some View {
    NavigationSplitView {
      SidebarView(browser: browser)
        .navigationSplitViewColumnWidth(
          min: Metrics.Column.sidebarMin, ideal: Metrics.Column.sidebarIdeal,
          max: Metrics.Column.sidebarMax
        )
    } content: {
      ContentColumnView(browser: browser)
        .navigationSplitViewColumnWidth(
          min: Metrics.Column.contentMin, ideal: Metrics.Column.contentIdeal,
          max: Metrics.Column.contentMax
        )
    } detail: {
      DetailView(browser: browser)
        .navigationSplitViewColumnWidth(
          min: Metrics.Column.detailMin, ideal: Metrics.Column.detailIdeal
        )
    }
    .navigationSplitViewStyle(.balanced)
    .searchable(
      text: $browser.searchText, isPresented: $browser.searchPresented,
      prompt: "Search APIs"
    )
    .toolbar {
      ToolbarItem {
        ComparePicker(browser: browser)
      }
      // The kind filter shapes the tree and search, which the compare
      // list does not use.
      if !browser.isComparing {
        ToolbarItem {
          KindFilterControl(browser: browser)
        }
      }
      ToolbarSpacer(.fixed)
      ToolbarItem(placement: .primaryAction) {
        if coordinator.selectedMissingIndex != nil {
          EmptyView()
        } else if let reindexing = coordinator.reindexingModule {
          ProgressView().controlSize(.small)
            .accessibilityLabel("Re-indexing \(reindexing)")
        } else if let module = browser.selectedFramework?.moduleName {
          Button {
            Task { await coordinator.reindexModule(module) }
          } label: {
            Label("Re-index \(module)", systemImage: "arrow.clockwise")
          }
          .help("Re-index \(module) only")
        } else {
          Button {
            Task { await coordinator.reindex() }
          } label: {
            Label("Re-index All", systemImage: "arrow.clockwise")
          }
          .help("Re-index everything from the latest SDKs")
        }
      }
    }
    .safeAreaInset(edge: .top) {
      let showStorageWarning =
        coordinator.storageMode == .inMemoryFallback && !storageWarningDismissed
      if coordinator.hasPendingChanges || browser.loadError != nil
        || showStorageWarning
      {
        VStack(spacing: Spacing.small) {
          if showStorageWarning {
            Banner(
              icon: "externaldrive.badge.exclamationmark",
              message: Text(
                "Couldn't open the saved index, so changes won't be kept after you quit."
              ),
              onDismiss: { storageWarningDismissed = true }
            )
          }
          if coordinator.hasPendingChanges {
            Banner(
              icon: "arrow.triangle.2.circlepath",
              message: Text(
                "Installed SDKs or Xcode changed since the index was built."
              ),
              action: BannerAction(title: "Re-index All") {
                Task { await coordinator.reindex() }
              }
            )
          }
          if let error = browser.loadError {
            Banner(
              icon: "exclamationmark.triangle",
              message: Text(verbatim: error),
              onDismiss: { browser.dismissLoadError() }
            )
          }
        }
        .padding(.top, Spacing.small)
      }
    }
    .alert(
      "Couldn't re-index",
      isPresented: Binding(
        get: { coordinator.reindexError != nil },
        set: { if !$0 { coordinator.clearReindexError() } }
      )
    ) {
      Button("OK") { coordinator.clearReindexError() }
    } message: {
      if let error = coordinator.reindexError {
        Text(error)
      }
    }
  }
}
