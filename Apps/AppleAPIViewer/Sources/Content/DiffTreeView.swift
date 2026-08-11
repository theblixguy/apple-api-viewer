import AppleAPIViewerCore
import CoreModel
import SwiftUI
import SymbolGraphIndex

enum DiffCategory: String, CaseIterable {
  case added
  case removed
  case changed
}

enum DiffRowID: Hashable {
  case category(DiffCategory)
  case symbol(DiffCategory, String)

  static let categoryRoots = Set(DiffCategory.allCases.map(Self.category))
}

struct DiffTreeView: View {
  @Bindable var browser: BrowserModel
  let module: String
  @State private var trees: FrameworkDiffTrees?
  @State private var selectedID: DiffRowID?
  @State private var expandedIDs = DiffRowID.categoryRoots
  @State private var isLoading = false
  @State private var retryToken = 0
  @Environment(\.openURL) private var openURL

  private struct ReloadKey: Hashable {
    let module: String
    let source: Source.ID?
    let revision: Int
    let retryToken: Int
  }

  var body: some View {
    // This view owns the disclosure state, like the browse tree, so a
    // double-click and the arrow keys can expand and collapse branches
    // and the category groups.
    List(selection: $selectedID) {
      group(.added, title: "Added", nodes: displayNodes(for: .added))
      group(.removed, title: "Removed", nodes: displayNodes(for: .removed))
      group(.changed, title: "Changed", nodes: displayNodes(for: .changed))
    }
    .contextMenu(forSelectionType: DiffRowID.self) { ids in
      if let id = ids.first, case let .symbol(category, usr) = id,
         let node = node(withUSR: usr, in: category)
      {
        symbolActions(
          name: node.symbol.name, url: documentationURL(for: node),
          openURL: openURL
        )
      }
    } primaryAction: { ids in
      guard let id = ids.first else { return }
      switch id {
      case .category:
        toggleExpansion(of: id)
      case let .symbol(category, usr):
        guard let node = node(withUSR: usr, in: category) else { return }
        if node.children.isEmpty {
          openURL(documentationURL(for: node))
        } else {
          toggleExpansion(of: id)
        }
      }
    }
    .labelReservedIconWidth(IconSize.kindGlyphWidth)
    .overlay {
      // A failed or canceled read leaves `trees` nil. Without the split,
      // that state would present as "No differences", which the indexes
      // do not support.
      if isLoading, trees == nil {
        ProgressView()
      } else if trees == nil, !isLoading {
        ContentUnavailableView {
          Label(
            "Couldn't load the differences",
            systemImage: "exclamationmark.triangle"
          )
        } description: {
          Text("Something interrupted the load.")
        } actions: {
          Button("Try Again") { retryToken += 1 }
        }
      } else if let focus = browser.focusedDiff, isFocusEmpty {
        ContentUnavailableView {
          Label("No changes", systemImage: "checkmark.circle")
        } description: {
          Text("\(focus.name) is the same in both indexes.")
        } actions: {
          Button("Show All Differences") { browser.focusedDiff = nil }
        }
      } else if trees?.isEmpty == true {
        ContentUnavailableView(
          "No differences",
          systemImage: "plus.forwardslash.minus",
          description: Text(
            "Both indexes record the same API for \(module)."
          )
        )
      }
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      if let focus = browser.focusedDiff, trees != nil, !isFocusEmpty {
        HStack(spacing: Spacing.small) {
          Text("Showing only \(focus.name)")
            .font(.callout)
            .lineLimit(1)
          Spacer(minLength: 0)
          Button("Show All") { browser.focusedDiff = nil }
        }
        .padding(Spacing.medium)
        .background(.bar)
      }
    }
    .task(
      id: ReloadKey(
        module: module, source: browser.comparisonSource,
        revision: browser.dataRevision, retryToken: retryToken
      )
    ) {
      isLoading = true
      defer { isLoading = false }
      if let result = await browser.diffTrees(forModule: module) {
        trees = result
        selectFocusedRow()
      }
    }
    .onChange(of: module) {
      // The view keeps its state across a framework switch. Without this,
      // the list would show the previous framework's diff while the new
      // one loads.
      trees = nil
      expandedIDs = DiffRowID.categoryRoots
    }
    .onChange(of: selectedID) { _, id in
      browser.selectedDiffEntry = id.flatMap(entry)
    }
    .onKeyPress(.rightArrow) {
      guard let id = selectedID, hasChildren(id), !expandedIDs.contains(id)
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

  @ViewBuilder private func group(
    _ category: DiffCategory, title: LocalizedStringKey,
    nodes: [SymbolTreeNode]
  ) -> some View {
    if !nodes.isEmpty {
      DisclosureGroup(isExpanded: expansion(for: .category(category))) {
        DiffOutline(
          category: category,
          nodes: nodes,
          changesByUSR: trees?.changesByUSR ?? [:],
          moduleName: module,
          browser: browser,
          expandedIDs: $expandedIDs
        )
      } label: {
        // The tag sits on the label, not the group. A tag on the group
        // would apply to every row it contains, and one click would then
        // select the whole category.
        Text(title)
          .fontWeight(.semibold)
          .badge(matchCount(in: nodes))
          .tag(DiffRowID.category(category))
      }
    }
  }

  private func matchCount(in nodes: [SymbolTreeNode]) -> Int {
    nodes.reduce(0) {
      $0 + ($1.isMatch ? 1 : 0) + matchCount(in: $1.children)
    }
  }

  private func nodes(for category: DiffCategory) -> [SymbolTreeNode] {
    switch category {
    case .added: trees?.added ?? []
    case .removed: trees?.removed ?? []
    case .changed: trees?.changed ?? []
    }
  }

  // A focused comparison shows the subtree rooted at the focused symbol,
  // so a type's diff includes the changes to its members.
  private func displayNodes(for category: DiffCategory) -> [SymbolTreeNode] {
    let all = nodes(for: category)
    guard let focus = browser.focusedDiff else { return all }
    return firstNode(withUSR: focus.usr, in: all).map { [$0] } ?? []
  }

  private var isFocusEmpty: Bool {
    DiffCategory.allCases.allSatisfy { displayNodes(for: $0).isEmpty }
  }

  private func selectFocusedRow() {
    guard let focus = browser.focusedDiff, selectedID == nil else { return }
    for category in DiffCategory.allCases {
      guard let node = firstNode(withUSR: focus.usr, in: nodes(for: category))
      else { continue }
      let id = DiffRowID.symbol(category, node.symbol.usr)
      selectedID = id
      if !node.children.isEmpty { expandedIDs.insert(id) }
      return
    }
  }

  private func node(
    withUSR usr: String, in category: DiffCategory
  ) -> SymbolTreeNode? {
    firstNode(withUSR: usr, in: nodes(for: category))
  }

  private func firstNode(
    withUSR usr: String, in nodes: [SymbolTreeNode]
  ) -> SymbolTreeNode? {
    for node in nodes {
      if node.symbol.usr == usr { return node }
      if let found = firstNode(withUSR: usr, in: node.children) {
        return found
      }
    }
    return nil
  }

  private func entry(for id: DiffRowID) -> DiffEntry? {
    guard case let .symbol(category, usr) = id,
          let node = node(withUSR: usr, in: category)
    else {
      return nil
    }
    let change = trees?.changesByUSR[usr]
    let entryCategory: DiffEntry.Category =
      switch category {
      case .added: .added
      case .removed: .removed
      case .changed: .changed(change?.reasons ?? [])
      }
    return DiffEntry(
      category: entryCategory, symbol: node.symbol, change: change
    )
  }

  private func hasChildren(_ id: DiffRowID) -> Bool {
    switch id {
    case .category: true
    case let .symbol(category, usr):
      node(withUSR: usr, in: category)?.children.isEmpty == false
    }
  }

  private func toggleExpansion(of id: DiffRowID) {
    if expandedIDs.contains(id) {
      expandedIDs.remove(id)
    } else {
      expandedIDs.insert(id)
    }
  }

  private func expansion(for id: DiffRowID) -> Binding<Bool> {
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

  private func documentationURL(for node: SymbolTreeNode) -> URL {
    browser.documentationURL(
      framework: module, pathComponents: node.symbol.pathComponents
    )
  }
}

private struct DiffOutline: View {
  let category: DiffCategory
  let nodes: [SymbolTreeNode]
  let changesByUSR: [String: SymbolChange]
  let moduleName: String
  let browser: BrowserModel
  @Binding var expandedIDs: Set<DiffRowID>

  // The wrapper scopes each row's identity to its category. The same
  // symbol can appear in two categories' trees, for example as an
  // unchanged ancestor, and the List needs the two rows kept apart.
  private struct DiffNode: Identifiable {
    let category: DiffCategory
    let node: SymbolTreeNode
    var id: DiffRowID { .symbol(category, node.symbol.usr) }
  }

  var body: some View {
    ForEach(nodes.map { DiffNode(category: category, node: $0) }) { wrapper in
      if wrapper.node.children.isEmpty {
        row(for: wrapper.node)
      } else {
        DisclosureGroup(isExpanded: expansion(for: wrapper.id)) {
          DiffOutline(
            category: category,
            nodes: wrapper.node.children,
            changesByUSR: changesByUSR,
            moduleName: moduleName,
            browser: browser,
            expandedIDs: $expandedIDs
          )
        } label: {
          row(for: wrapper.node)
        }
      }
    }
  }

  private func row(for node: SymbolTreeNode) -> some View {
    DiffSymbolRow(
      node: node,
      category: category,
      reasons: node.isMatch ? changesByUSR[node.symbol.usr]?.reasons : nil
    )
    .draggable(
      browser.documentationURL(
        framework: moduleName, pathComponents: node.symbol.pathComponents
      )
    )
  }

  private func expansion(for id: DiffRowID) -> Binding<Bool> {
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
