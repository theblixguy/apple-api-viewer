import AppleAPIViewerCore
import CoreModel
import Sparkle
import SwiftUI

struct AppleAPIViewerCommands: Commands {
  let coordinator: IndexCoordinator
  let browser: BrowserModel
  let updater: SPUUpdater

  private var selectedModuleReindexTitle: LocalizedStringKey {
    if let module = browser.selectedFramework?.moduleName {
      "Re-index \(module)"
    } else {
      "Re-index Selected Module"
    }
  }

  var body: some Commands {
    CommandGroup(after: .appInfo) {
      Button("Check for Updates…") { updater.checkForUpdates() }
    }

    CommandGroup(after: .textEditing) {
      Button("Find…") { browser.searchPresented = true }
        .keyboardShortcut("f", modifiers: .command)
    }

    CommandMenu("Filter") {
      PlatformFilterMenuContent(browser: browser)
    }

    CommandMenu("Index") {
      Button("Re-index All") { Task { await coordinator.reindex() } }
        .keyboardShortcut("r", modifiers: [.command, .shift])
        .disabled(
          coordinator.isMutatingIndex || coordinator.selectedMissingIndex != nil
        )

      Button(selectedModuleReindexTitle) {
        guard let module = browser.selectedFramework?.moduleName else { return }
        Task { await coordinator.reindexModule(module) }
      }
      .keyboardShortcut("r", modifiers: .command)
      .disabled(
        browser.selectedFramework == nil || coordinator.isMutatingIndex
          || coordinator.selectedMissingIndex != nil
      )

      if !coordinator.availableXcodes.isEmpty {
        Divider()
        Menu("Index From") {
          ForEach(coordinator.availableXcodes) { xcode in
            Button {
              Task { await coordinator.chooseDefaultXcode(xcode) }
            } label: {
              if coordinator.xcode == xcode {
                Label(xcode.displayName, systemImage: "checkmark")
              } else {
                Text(xcode.displayName)
              }
            }
          }
        }
      }

      Divider()
      SettingsLink {
        Text("Manage Xcodes…")
      }
    }
  }
}
