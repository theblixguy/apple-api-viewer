import AppleAPIViewerCore
import CoreModel
import SwiftUI
import SymbolGraphIndex
import TipKit

struct SymbolTreeView: View {
  let browser: BrowserModel
  let pick: FrameworkPick
  @State private var nodes: [SymbolTreeNode] = []
  @State private var selectedID: SymbolTreeNode.ID?
  @State private var expandedIDs: Set<SymbolTreeNode.ID> = []
  @State private var isLoading = true
  @Environment(\.openURL) private var openURL

  var body: some View {
    // This view owns the disclosure state, not `List(_:children:)`. List
    // keeps that state private. A double-click and the arrow keys need
    // access to the state to expand and collapse branches.
    // Double-clicks arrive through `primaryAction`, not a row gesture. A row
    // gesture would swallow the first click on the row text and break
    // selection.
    List(selection: $selectedID) {
      SymbolOutline(
        nodes: nodes, moduleName: pick.moduleName, browser: browser,
        expandedIDs: $expandedIDs
      )
    }
    .contextMenu(forSelectionType: SymbolTreeNode.ID.self) { ids in
      if let id = ids.first, let node = Self.firstNode(withID: id, in: nodes) {
        symbolActions(
          name: node.symbol.name, url: documentationURL(for: node),
          openURL: openURL
        )
      }
    } primaryAction: { ids in
      guard let id = ids.first, let node = Self.firstNode(withID: id, in: nodes)
      else { return }
      if node.children.isEmpty {
        openURL(documentationURL(for: node))
      } else if expandedIDs.contains(id) {
        expandedIDs.remove(id)
      } else {
        expandedIDs.insert(id)
      }
    }
    .labelReservedIconWidth(IconSize.kindGlyphWidth)
    .popoverTip(DoubleClickTreeTip())
    .overlay {
      if nodes.isEmpty {
        if isLoading {
          ProgressView()
        } else {
          ContentUnavailableView("No new APIs", systemImage: "checkmark.circle")
        }
      }
    }
    .task(
      id: TreeReloadKey(
        pick: pick, versions: browser.versions(for: pick.platform),
        kinds: browser.selectedKinds,
        revision: browser.dataRevision
      )
    ) {
      isLoading = true
      // Do not reset `selectedID` here. The List drops a now-missing
      // selection automatically, and a reset while `nodes` reloads would
      // trigger the "reentrant NSTableView delegate" warning.
      // The load can return nil when it is canceled or when it fails.
      // A nil result leaves the current tree in place.
      if let result = await browser.tree(for: pick) { nodes = result }
      isLoading = false
    }
    .onChange(of: pick) { expandedIDs = [] }
    .onChange(of: selectedID) { _, id in
      browser.selectedSymbol = id.map {
        SymbolReference(usr: $0, moduleName: pick.moduleName)
      }
    }
    .onKeyPress(.rightArrow) {
      guard let id = selectedID,
            let node = Self.firstNode(withID: id, in: nodes),
            !node.children.isEmpty, !expandedIDs.contains(id)
      else { return .ignored }
      expandedIDs.insert(id)
      return .handled
    }
    .onKeyPress(.leftArrow) {
      guard let id = selectedID, expandedIDs.contains(id) else {
        return .ignored
      }
      expandedIDs.remove(id)
      return .handled
    }
  }

  // MARK: - Private

  private func documentationURL(for node: SymbolTreeNode) -> URL {
    browser.documentationURL(
      framework: pick.moduleName, pathComponents: node.symbol.pathComponents
    )
  }

  private static func firstNode(
    withID id: SymbolTreeNode.ID, in nodes: [SymbolTreeNode]
  ) -> SymbolTreeNode? {
    for node in nodes {
      if node.id == id { return node }
      if let found = firstNode(withID: id, in: node.children) { return found }
    }
    return nil
  }
}

private struct SymbolOutline: View {
  let nodes: [SymbolTreeNode]
  let moduleName: String
  let browser: BrowserModel
  @Binding var expandedIDs: Set<SymbolTreeNode.ID>

  var body: some View {
    ForEach(nodes) { node in
      if node.children.isEmpty {
        row(for: node)
      } else {
        DisclosureGroup(isExpanded: expansion(for: node.id)) {
          SymbolOutline(
            nodes: node.children, moduleName: moduleName, browser: browser,
            expandedIDs: $expandedIDs
          )
        } label: {
          row(for: node)
        }
      }
    }
  }

  private func row(for node: SymbolTreeNode) -> some View {
    SymbolRow(node: node)
      .draggable(
        browser.documentationURL(
          framework: moduleName, pathComponents: node.symbol.pathComponents
        )
      )
  }

  private func expansion(for id: SymbolTreeNode.ID) -> Binding<Bool> {
    Binding(
      get: { expandedIDs.contains(id) },
      set: { expanded in
        if expanded {
          expandedIDs.insert(id)
        } else {
          expandedIDs.remove(id)
        }
      }
    )
  }
}

private struct TreeReloadKey: Hashable {
  let pick: FrameworkPick
  let versions: [SemanticVersion]
  let kinds: Set<SymbolKind>
  let revision: Int
}
