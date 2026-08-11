import AppleAPIViewerCore
import CoreModel
import SwiftUI
import SymbolGraphIndex

struct DiffListView: View {
  @Bindable var browser: BrowserModel
  let module: String
  @State private var diff: FrameworkDiff?
  @State private var isLoading = false

  private struct ReloadKey: Hashable {
    let module: String
    let source: Source.ID?
    let revision: Int
  }

  var body: some View {
    Group {
      if let diff, !diff.isEmpty {
        List(selection: $browser.selectedDiffEntry) {
          if !diff.added.isEmpty {
            Section("Added (\(diff.added.count))") {
              ForEach(diff.added) { symbol in
                row(DiffEntry(category: .added, symbol: symbol))
              }
            }
          }
          if !diff.removed.isEmpty {
            Section("Removed (\(diff.removed.count))") {
              ForEach(diff.removed) { symbol in
                row(DiffEntry(category: .removed, symbol: symbol))
              }
            }
          }
          if !diff.changed.isEmpty {
            Section("Changed (\(diff.changed.count))") {
              ForEach(diff.changed) { change in
                row(
                  DiffEntry(
                    category: .changed(change.reasons), symbol: change.new
                  )
                )
              }
            }
          }
        }
      } else if isLoading {
        ProgressView()
      } else {
        ContentUnavailableView(
          "No differences",
          systemImage: "plus.forwardslash.minus",
          description: Text(
            "Both indexes record the same API for \(module)."
          )
        )
      }
    }
    .task(
      id: ReloadKey(
        module: module, source: browser.comparisonSource,
        revision: browser.dataRevision
      )
    ) {
      isLoading = true
      defer { isLoading = false }
      // The view keeps its state across a framework switch. Without this,
      // the list would show the previous framework's diff while the new
      // one loads.
      if diff?.moduleName != module { diff = nil }
      diff = await browser.diff(forModule: module)
    }
  }

  // MARK: - Private

  private func row(_ entry: DiffEntry) -> some View {
    DiffEntryRow(entry: entry).tag(entry)
  }
}
