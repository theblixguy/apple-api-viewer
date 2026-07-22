import AppleAPIViewerCore
import SwiftUI

struct ContentColumnView: View {
  let browser: BrowserModel

  var body: some View {
    Group {
      if browser.isSearching {
        SearchResultsView(browser: browser)
      } else if let pick = browser.selectedFramework {
        SymbolTreeView(browser: browser, pick: pick)
      } else {
        ContentUnavailableView(
          "No framework selected",
          systemImage: "sidebar.squares.left",
          description: Text("Select a framework to see what's new.")
        )
      }
    }
    .navigationTitle(
      browser.isSearching
        ? String(localized: "Search")
        : (browser.selectedFramework?.moduleName ?? String(localized: "APIs"))
    )
    .task { await browser.runSearch() }
  }
}
