import AppleAPIViewerCore
import CoreModel
import IndexStore
import SwiftUI

struct ComparePicker: View {
  @Bindable var browser: BrowserModel
  @State private var candidates: [IndexedSource] = []

  private struct ReloadKey: Hashable {
    let source: Source.ID?
    let revision: Int
  }

  var body: some View {
    Menu {
      Picker("Compare with", selection: selection) {
        Text("Off").tag(Source.ID?.none)
        ForEach(candidates) { candidate in
          Text(verbatim: candidate.source.displayName)
            .tag(Source.ID?.some(candidate.id))
        }
      }
      .pickerStyle(.inline)
    } label: {
      Label("Compare", systemImage: "plus.forwardslash.minus")
    }
    .disabled(candidates.isEmpty && !browser.isComparing)
    .help("Compare the active index with another Xcode's index")
    .task(
      id: ReloadKey(
        source: browser.activeSource, revision: browser.dataRevision
      )
    ) {
      candidates = await browser.comparisonCandidates()
    }
  }

  // MARK: - Private

  private var selection: Binding<Source.ID?> {
    Binding(
      get: { browser.comparisonSource },
      set: { id in
        if let candidate = candidates.first(where: { $0.id == id }) {
          browser.compare(against: candidate.source)
        } else {
          browser.stopComparing()
        }
      }
    )
  }
}
