import AppleAPIViewerCore
import CoreModel
import IndexStore
import SwiftUI
import SymbolGraphIndex

struct SearchResultsView: View {
  @Bindable var browser: BrowserModel
  @Environment(\.openURL) private var openURL

  var body: some View {
    List(selection: $browser.selectedSymbol) {
      ForEach(browser.searchHits) { hit in
        let url = browser.documentationURL(
          framework: hit.moduleName, pathComponents: hit.pathComponents
        )
        Label {
          VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(hit.title)
            Text(hit.moduleName).font(.caption).foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: SymbolDisplay.systemImageName(for: hit.kind))
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
        }
        .tag(SymbolReference(usr: hit.usr, moduleName: hit.moduleName))
        .draggable(url)
        .contextMenu {
          symbolActions(name: hit.name, url: url, openURL: openURL)
        }
        .accessibilityElement(children: .combine)
      }
    }
    .labelReservedIconWidth(IconSize.kindGlyphWidth)
    .overlay {
      if browser.searchHits.isEmpty {
        ContentUnavailableView.search(text: browser.searchText)
      }
    }
  }
}
