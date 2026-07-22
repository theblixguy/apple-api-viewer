import AppleAPIViewerCore
import SwiftUI

struct RootView: View {
  let coordinator: IndexCoordinator
  let browser: BrowserModel

  var body: some View {
    content
      .onChange(of: coordinator.activeSourceID, initial: true) { _, id in
        browser.activeSource = id
      }
      .onChange(of: coordinator.isMutatingIndex) { was, now in
        if was, !now { browser.bumpDataRevision() }
      }
  }

  @ViewBuilder private var content: some View {
    switch coordinator.status {
    case .preparing:
      StatusCard(
        systemImage: "hourglass", title: "Preparing",
        message: Text("Locating Xcode and SDKs…")
      ) {
        ProgressView().controlSize(.small)
      }
    case .needsIndexing:
      StatusCard(
        systemImage: "tray.and.arrow.down",
        title: "Build the API index",
        message: Text(
          "Symbols are extracted from your latest SDKs, once per Xcode build."
        )
      ) {
        Button("Build index") { Task { await coordinator.reindex() } }
          .buttonStyle(.borderedProminent)
      }
    case let .indexing(progress):
      IndexingView(
        progress: progress,
        xcode: coordinator.xcode?.displayName,
        isPaused: coordinator.isPaused,
        onPauseResume: {
          if coordinator.isPaused {
            coordinator.resumeIndexing()
          } else {
            coordinator.pauseIndexing()
          }
        },
        onCancel: { coordinator.cancelIndexing() }
      )
    case .canceling:
      StatusCard(
        systemImage: "stop.circle",
        title: "Canceling the index build",
        message: Text("Stopping the modules in progress.")
      ) {
        ProgressView().controlSize(.small)
      }
    case let .failed(message):
      StatusCard(
        systemImage: "exclamationmark.triangle",
        title: "Couldn't build the index",
        message: Text(verbatim: message)
      ) {
        Button("Try again") { Task { await coordinator.prepare() } }
          .buttonStyle(.bordered)
      }
    case .ready:
      BrowserView(browser: browser, coordinator: coordinator)
        .task(id: browser.dataRevision) { await browser.loadPickerData() }
    }
  }
}
