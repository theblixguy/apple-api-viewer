import AppleAPIViewerCore
import SwiftUI
import SymbolGraphIndex

struct DetailView: View {
  let browser: BrowserModel
  @State private var state: LoadState = .empty

  private enum LoadState {
    case empty
    case loading
    case loaded(symbol: IndexedSymbol, moduleName: String)
    case notFound
  }

  var body: some View {
    Group {
      switch state {
      case .empty:
        if let pick = browser.selectedFramework {
          FrameworkOverviewView(browser: browser, pick: pick)
        } else {
          ContentUnavailableView(
            "No API selected",
            systemImage: "doc.text.magnifyingglass",
            description: Text("Select an API to see details.")
          )
        }
      case .loading:
        ProgressView()
      case let .loaded(symbol, moduleName):
        SymbolDetailContent(
          symbol: symbol,
          moduleName: moduleName,
          documentationURL: browser.documentationURL(
            for: symbol, in: moduleName
          )
        )
      case .notFound:
        ContentUnavailableView(
          "Couldn't load this API",
          systemImage: "exclamationmark.triangle",
          description: Text(
            "This API isn't in the current index. Re-indexing may help."
          )
        )
      }
    }
    // The revision in the key re-resolves the symbol after a re-index or
    // an Xcode switch.
    .task(id: ReloadKey(
      selection: browser.selectedSymbol, revision: browser.dataRevision
    )) {
      guard let reference = browser.selectedSymbol else {
        state = .empty
        return
      }
      state = .loading
      if let symbol = await browser.resolveSymbol(reference) {
        state = .loaded(symbol: symbol, moduleName: reference.moduleName)
      } else if !Task.isCancelled {
        state = .notFound
      }
    }
  }

  private struct ReloadKey: Equatable {
    let selection: SymbolReference?
    let revision: Int
  }
}
