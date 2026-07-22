#if DEBUG
  import AppKit
  import AppleAPIViewerCore
  import IndexOrchestration
  import SwiftUI
  import TipKit

  struct DebugSettingsView: View {
    let coordinator: IndexCoordinator

    @State private var outcome: Outcome?
    @State private var confirmingRegistryReset = false

    private struct Outcome {
      let title: String
      let message: String
      var offersQuit = false
    }

    var body: some View {
      Form {
        Section {
          Button("Reset tips") { resetTips() }
        } footer: {
          Text(
            "Clears saved tip history at the next launch, so dismissed and expired tips show again."
          )
        }

        Section {
          Button("Reveal database in Finder") { revealDatabase() }
          Button("Copy database path") { copyDatabasePath() }
        } footer: {
          Text("The index the app and the apple-api-viewer-cli tool share.")
        }

        Section {
          Button("Reset Xcode list…", role: .destructive) {
            confirmingRegistryReset = true
          }
          .confirmationDialog(
            "Reset the Xcode list?",
            isPresented: $confirmingRegistryReset, titleVisibility: .visible
          ) {
            Button("Reset list", role: .destructive) { resetRegistryDefaults() }
          } message: {
            Text(
              "Forgets manually added Xcodes and the pinned choice. Stored indexes stay."
            )
          }
        }
      }
      .formStyle(.grouped)
      .frame(width: 540, height: 400)
      .alert(
        outcome?.title ?? "",
        isPresented: Binding(
          get: { outcome != nil }, set: { if !$0 { outcome = nil } }
        ),
        presenting: outcome
      ) { outcome in
        if outcome.offersQuit {
          Button("Quit Apple API Viewer") { NSApp.terminate(nil) }
          Button("Later", role: .cancel) {}
        } else {
          Button("OK") {}
        }
      } message: { outcome in
        Text(verbatim: outcome.message)
      }
    }

    // MARK: - Actions

    private func resetTips() {
      UserDefaults.standard.set(true, forKey: DebugFlags.resetTipsAtLaunch)
      outcome = Outcome(
        title: "Tips will reset",
        message:
        "Tip history can only be cleared at launch, so tips show again the next time the app opens.",
        offersQuit: true
      )
    }

    private func revealDatabase() {
      guard let url = try? AppPaths.databaseURL() else {
        outcome = Outcome(
          title: "Couldn't find the database",
          message: "The database path didn't resolve."
        )
        return
      }
      NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copyDatabasePath() {
      guard let url = try? AppPaths.databaseURL() else {
        outcome = Outcome(
          title: "Couldn't find the database",
          message: "The database path didn't resolve."
        )
        return
      }
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(
        url.path(percentEncoded: false), forType: .string
      )
    }

    private func resetRegistryDefaults() {
      UserDefaults(suiteName: XcodeRegistry.sharedSuiteName)?
        .removePersistentDomain(forName: XcodeRegistry.sharedSuiteName)
      Task { await coordinator.refreshXcodes() }
      outcome = Outcome(
        title: "Xcode list reset",
        message: "The list now shows only auto-detected Xcodes."
      )
    }
  }
#endif
