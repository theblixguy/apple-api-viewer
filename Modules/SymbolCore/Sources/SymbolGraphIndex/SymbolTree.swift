import Foundation

/// A node in the tree of types and their members shown in the UI.
public struct SymbolTreeNode: Sendable, Hashable, Identifiable {
  /// The symbol at this node.
  public let symbol: IndexedSymbol

  /// A Boolean value that indicates whether the symbol itself matches the
  /// active version selection. A symbol can be present only because it
  /// encloses a matching descendant, for example a pre-existing class that
  /// gained a new method.
  public let isMatch: Bool

  /// The node's child symbols.
  public let children: [SymbolTreeNode]

  /// A Boolean value that indicates whether this node or any descendant is
  /// itself a match.
  public let containsMatch: Bool

  /// A stable identifier, the symbol's USR.
  public var id: String { symbol.usr }

  /// Creates a tree node from a symbol, its match state, and its children.
  ///
  /// - Parameters:
  ///   - symbol: The symbol at this node.
  ///   - isMatch: A Boolean value that indicates whether the symbol itself
  ///     matches the active version selection.
  ///   - children: The node's child symbols.
  public init(symbol: IndexedSymbol, isMatch: Bool, children: [SymbolTreeNode])
  {
    self.symbol = symbol
    self.isMatch = isMatch
    self.children = children
    containsMatch = isMatch || children.contains(where: \.containsMatch)
  }
}

extension FrameworkIndex {
  /// Returns the tree of symbols that are new for `selections`, optionally
  /// limited to certain symbol kinds.
  ///
  /// The tree includes matching symbols along with every ancestor type up to
  /// the top level. This way a new member appears under its enclosing type,
  /// even when that type is not itself new. A symbol whose parent is outside
  /// this framework, such as one added to a foreign type through an
  /// extension, appears as a root.
  ///
  /// - Parameters:
  ///   - selections: The OS releases in which an API must be new to count as
  ///     a match.
  ///   - kinds: When non-`nil`, only symbols of these kinds count as
  ///     matches, but enclosing types still appear as ancestors. `nil`
  ///     matches all.
  /// - Returns: The roots of the new-symbol tree, empty when nothing
  ///   matches.
  public func newSymbolTree(
    for selections: [VersionSelection], kinds: Set<SymbolKind>? = nil
  )
    -> [SymbolTreeNode]
  {
    let byUSR = Dictionary(
      symbols.map { ($0.usr, $0) }, uniquingKeysWith: { first, _ in first }
    )
    let matchUSRs = Set(
      symbols.filter {
        $0.wasIntroduced(inAnyOf: selections)
          && (kinds?.contains($0.kind) ?? true)
      }.map(\.usr)
    )
    guard !matchUSRs.isEmpty else { return [] }

    var included = Set<String>()
    for matchUSR in matchUSRs {
      var current: String? = matchUSR
      // A parent USR outside byUSR means a foreign type gained members
      // through an extension. That parent must stay out of included, or
      // its children would key under a USR with no node and vanish from
      // the tree.
      while let usr = current, byUSR[usr] != nil,
            included.contains(usr) == false
      {
        included.insert(usr)
        current = byUSR[usr]?.parentUSR
      }
    }

    var childrenByParent: [String?: [IndexedSymbol]] = [:]
    for usr in included {
      guard let symbol = byUSR[usr] else { continue }
      let parent = symbol.parentUSR.flatMap { included.contains($0) ? $0 : nil }
      childrenByParent[parent, default: []].append(symbol)
    }

    func makeNode(_ symbol: IndexedSymbol) -> SymbolTreeNode {
      let children = (childrenByParent[symbol.usr] ?? [])
        .sorted(by: Self.displayOrder)
        .map(makeNode)
      return SymbolTreeNode(
        symbol: symbol, isMatch: matchUSRs.contains(symbol.usr),
        children: children
      )
    }

    return (childrenByParent[nil] ?? [])
      .sorted(by: Self.displayOrder)
      .map(makeNode)
  }

  private static func displayOrder(_ lhs: IndexedSymbol, _ rhs: IndexedSymbol)
    -> Bool
  {
    lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
  }
}
