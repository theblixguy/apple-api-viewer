import SymbolGraphIndex

/// One framework's diff shaped as trees for the compare list.
///
/// Each category's tree contains the diffed symbols along with every
/// ancestor type up to the top level, like the browse tree. The added and
/// changed trees come from the new snapshot, and the removed tree comes
/// from the old one.
public nonisolated struct FrameworkDiffTrees: Sendable, Hashable {
  /// The tree of symbols that only the new snapshot contains.
  public let added: [SymbolTreeNode]

  /// The tree of symbols that only the old snapshot contains.
  public let removed: [SymbolTreeNode]

  /// The tree of symbols that both snapshots contain with differences.
  public let changed: [SymbolTreeNode]

  /// Each changed symbol's old and new records with their differences,
  /// keyed by the new record's USR.
  public let changesByUSR: [String: SymbolChange]

  /// A Boolean value that indicates whether the two snapshots record the
  /// same API.
  public var isEmpty: Bool {
    added.isEmpty && removed.isEmpty && changed.isEmpty
  }

  /// Creates the trees for the diff between an old and a new snapshot of
  /// one framework.
  ///
  /// - Parameters:
  ///   - old: The old snapshot.
  ///   - new: The new snapshot.
  public init(from old: FrameworkIndex, to new: FrameworkIndex) {
    let diff = FrameworkDiff(from: old, to: new)
    added = new.tree(matchingUSRs: Set(diff.added.map(\.usr)))
    removed = old.tree(matchingUSRs: Set(diff.removed.map(\.usr)))
    changed = new.tree(matchingUSRs: Set(diff.changed.map(\.new.usr)))
    changesByUSR = Dictionary(
      diff.changed.map { ($0.new.usr, $0) },
      uniquingKeysWith: { first, _ in first }
    )
  }
}
