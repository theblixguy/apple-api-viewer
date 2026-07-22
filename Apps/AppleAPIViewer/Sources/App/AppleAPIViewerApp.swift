import AppIntents
import AppleAPIViewerCore
import IndexOrchestration
import IndexStore
import Sparkle
import SwiftUI
import TipKit

@main
struct AppleAPIViewerApp: App {
  @State private var coordinator: IndexCoordinator
  @State private var browser: BrowserModel
  @AppStorage(AppPreference.menuBarSearch)
  private var menuBarSearchEnabled = true
  @Environment(\.scenePhase) private var scenePhase

  private let updaterController = SPUStandardUpdaterController(
    startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
  )

  init() {
    let databaseURL = try? AppPaths.databaseURL()
    let storageMode = IndexStore.bootstrap(at: databaseURL)
    let store = IndexStore()
    let coordinator = IndexCoordinator(
      store: store, storageMode: storageMode,
      databaseURL: storageMode == .persistent ? databaseURL : nil
    )
    let browser = BrowserModel(store: store)
    _coordinator = State(initialValue: coordinator)
    _browser = State(initialValue: browser)
    AppDependencyManager.shared.add(
      dependency: IntentServices(
        coordinator: coordinator, browser: browser, store: store
      )
    )
    #if DEBUG
      if UserDefaults.standard.bool(forKey: DebugFlags.resetTipsAtLaunch) {
        UserDefaults.standard.removeObject(
          forKey: DebugFlags.resetTipsAtLaunch
        )
        try? Tips.resetDatastore()
      }
    #endif
    try? Tips.configure()
  }

  var body: some Scene {
    WindowGroup(id: WindowID.main) {
      RootView(coordinator: coordinator, browser: browser)
        .frame(
          minWidth: Metrics.windowMinWidth, minHeight: Metrics.windowMinHeight
        )
        .task { await coordinator.prepare() }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active {
            Task { await coordinator.checkForChanges() }
          }
        }
    }
    .defaultSize(
      width: Metrics.windowDefaultWidth, height: Metrics.windowDefaultHeight
    )
    .windowResizability(.contentMinSize)
    .windowToolbarStyle(.unified)
    .commands {
      AppleAPIViewerCommands(
        coordinator: coordinator, browser: browser,
        updater: updaterController.updater
      )
    }

    MenuBarExtra(
      "Apple API Viewer", systemImage: "curlybraces",
      isInserted: $menuBarSearchEnabled
    ) {
      MenuBarSearchView(coordinator: coordinator, browser: browser)
    }
    .menuBarExtraStyle(.window)

    Settings {
      TabView {
        Tab("General", systemImage: "gearshape") {
          GeneralSettingsView(updater: updaterController.updater)
        }
        Tab("Xcodes", systemImage: "wrench.and.screwdriver") {
          XcodeSettingsView(coordinator: coordinator)
        }
        #if DEBUG
          Tab("Debug", systemImage: "ladybug") {
            DebugSettingsView(coordinator: coordinator)
          }
        #endif
      }
    }
  }
}
