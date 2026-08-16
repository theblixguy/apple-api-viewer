import AppleAPIViewerCore
import SwiftUI

struct ContentColumnView: View {
  let browser: BrowserModel

  var body: some View {
    Group {
      if browser.isSearching {
        SearchResultsView(browser: browser)
      } else if browser.isComparing {
        if let module = browser.selectedDiffModule {
          DiffTreeView(browser: browser, module: module)
        } else {
          ContentUnavailableView(
            "No framework selected",
            systemImage: "sidebar.squares.left",
            description: Text("Select a framework to see its differences.")
          )
        }
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
    .navigationTitle(navigationTitle)
    .task { await browser.runSearch() }
  }

  // MARK: - Private

  private var navigationTitle: String {
    if browser.isSearching {
      String(localized: "Search")
    } else if browser.isComparing {
      browser.selectedDiffModule ?? String(localized: "Differences")
    } else {
      browser.selectedFramework?.moduleName ?? String(localized: "APIs")
    }
  }
}
