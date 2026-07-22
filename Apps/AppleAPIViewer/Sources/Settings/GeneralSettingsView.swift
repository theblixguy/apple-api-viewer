import ServiceManagement
import Sparkle
import SwiftUI

struct GeneralSettingsView: View {
  let updater: SPUUpdater

  @AppStorage(AppPreference.menuBarSearch)
  private var menuBarSearchEnabled = true
  @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
  @State private var automaticUpdateChecks = true
  @State private var loginItemError: String?
  @State private var outcome: Outcome?

  private struct Outcome {
    let title: String
    let message: String
  }

  var body: some View {
    Form {
      Section {
        Toggle("Show search in the menu bar", isOn: $menuBarSearchEnabled)
        Toggle("Open at login", isOn: $launchAtLogin)
          .onChange(of: launchAtLogin) { _, isOn in
            updateLoginItem(isOn)
          }
        if let loginItemError {
          Text(verbatim: loginItemError)
            .font(.caption)
            .foregroundStyle(.red)
        }
      } footer: {
        Text(
          "Look up an API from any app without switching windows. Opening at login keeps the menu bar search available."
        )
      }

      Section {
        Toggle("Automatically check for updates", isOn: $automaticUpdateChecks)
          .onChange(of: automaticUpdateChecks) { _, isOn in
            updater.automaticallyChecksForUpdates = isOn
          }
      } footer: {
        Text("Updates download from the app's release feed.")
      }

      Section {
        Button("Install command line tool") { installCommandLineTool() }
      } footer: {
        Text(
          "Links the bundled apple-api-viewer-cli into /usr/local/bin so Terminal and scripts can run it."
        )
      }
    }
    .formStyle(.grouped)
    .frame(width: 540, height: 340)
    .onAppear {
      launchAtLogin = SMAppService.mainApp.status == .enabled
      automaticUpdateChecks = updater.automaticallyChecksForUpdates
    }
    .alert(
      outcome?.title ?? "",
      isPresented: Binding(
        get: { outcome != nil }, set: { if !$0 { outcome = nil } }
      ),
      presenting: outcome
    ) { _ in
      Button("OK") {}
    } message: { outcome in
      Text(verbatim: outcome.message)
    }
  }

  // MARK: - Actions

  private func updateLoginItem(_ isOn: Bool) {
    do {
      if isOn {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      loginItemError = nil
    } catch {
      loginItemError = error.localizedDescription
      launchAtLogin = SMAppService.mainApp.status == .enabled
    }
  }

  private func installCommandLineTool() {
    let sourceURL = Bundle.main.bundleURL.appending(
      path: "Contents/Helpers/apple_api_viewer_cli"
    )
    guard FileManager.default.fileExists(
      atPath: sourceURL.path(percentEncoded: false)
    )
    else {
      outcome = Outcome(
        title: "Couldn't install the command line tool",
        message:
        "The command line tool is missing from this copy of the app. Download the app again to restore it."
      )
      return
    }

    let destinationURL = URL(filePath: "/usr/local/bin/apple-api-viewer-cli")
    do {
      try? FileManager.default.removeItem(at: destinationURL)
      try FileManager.default.createSymbolicLink(
        at: destinationURL, withDestinationURL: sourceURL
      )
      outcome = Outcome(
        title: "Command line tool installed",
        message: "You can now run apple-api-viewer-cli in Terminal."
      )
    } catch {
      // A Mac without Intel-era Homebrew does not have /usr/local/bin, and
      // a bare ln will fail there.
      outcome = Outcome(
        title: "Couldn't install the command line tool",
        message: """
        The app can't write to /usr/local/bin. To finish installing, run this command in Terminal:

        sudo mkdir -p /usr/local/bin && sudo ln -sf "\(sourceURL
          .path(percentEncoded: false))" /usr/local/bin/apple-api-viewer-cli
        """
      )
    }
  }
}
