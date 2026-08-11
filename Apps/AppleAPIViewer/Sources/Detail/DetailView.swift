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
    // Search stays available in compare mode and resolves its hits from
    // the active index, so a search selection uses the browse path.
    if browser.isComparing, !browser.isSearching {
      compareContent
    } else {
      browseContent
    }
  }

  // MARK: - Private

  // A diff entry carries its full symbol record, so the compare detail
  // renders without a store read. A removed symbol has no record in the
  // active index to resolve against.
  @ViewBuilder private var compareContent: some View {
    if let entry = browser.selectedDiffEntry,
       let module = browser.selectedDiffModule
    {
      SymbolDetailContent(
        symbol: entry.symbol,
        moduleName: module,
        documentationURL: browser.documentationURL(
          for: entry.symbol, in: module
        )
      )
    } else {
      ContentUnavailableView(
        "No API selected",
        systemImage: "doc.text.magnifyingglass",
        description: Text("Select an API to see details.")
      )
    }
  }

  private var browseContent: some View {
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
