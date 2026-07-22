import AppleAPIViewerCore
import IndexOrchestration
import IndexStore
import SwiftUI
import TipKit
import UniformTypeIdentifiers

struct XcodeSettingsView: View {
  let coordinator: IndexCoordinator

  @State private var isImporting = false
  @State private var addError: String?

  var body: some View {
    Form {
      Section {
        if coordinator.xcodeEntries.isEmpty, coordinator.missingIndexes.isEmpty
        {
          Text("No Xcode found in /Applications.")
            .foregroundStyle(.secondary)
        } else {
          if !coordinator.xcodeEntries.isEmpty {
            AutomaticXcodeRow(coordinator: coordinator)
              .popoverTip(PerXcodeIndexTip())
            ForEach(coordinator.xcodeEntries) { entry in
              XcodeSettingsRow(entry: entry, coordinator: coordinator)
            }
          }
          ForEach(coordinator.missingIndexes) { indexed in
            MissingIndexRow(indexed: indexed, coordinator: coordinator)
          }
        }
      } header: {
        Text("Xcodes")
      } footer: {
        Text(
          "The index builds from the checked choice. An index whose Xcode is gone stays browsable until you delete it."
        )
      }

      Section {
        Button {
          isImporting = true
        } label: {
          Label("Add Xcode…", systemImage: "plus")
        }
      } footer: {
        Text("Add an Xcode from outside /Applications.")
      }
    }
    .formStyle(.grouped)
    .frame(width: 540, height: 460)
    .task { await coordinator.refreshXcodes() }
    .fileImporter(
      isPresented: $isImporting, allowedContentTypes: [.application]
    ) { result in
      switch result {
      case let .success(url):
        Task {
          do {
            try await coordinator.addXcode(at: url)
          } catch {
            addError = error.localizedDescription
          }
        }
      case let .failure(error):
        addError = error.localizedDescription
      }
    }
    .alert(
      "Couldn't add Xcode",
      isPresented: Binding(
        get: { addError != nil }, set: { if !$0 { addError = nil } }
      )
    ) {
      Button("OK") { addError = nil }
    } message: {
      if let addError { Text(verbatim: addError) }
    }
  }
}
