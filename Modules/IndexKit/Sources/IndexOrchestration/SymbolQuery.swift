import CoreModel
import IndexStore
import SymbolGraphIndex

/// The UI-free query API over a populated index.
///
/// Every read is scoped to one source, one Xcode's index.
public struct SymbolQuery: Sendable {
  private let store: IndexStore

  /// Creates a query backed by the given store.
  ///
  /// - Parameter store: The index store to read.
  public init(store: IndexStore) {
    self.store = store
  }

  /// Returns each indexed platform's selectable OS releases in `source`'s
  /// index, newest first.
  ///
  /// - Parameter source: The source whose index is read.
  /// - Returns: Each indexed platform's selectable OS releases, newest first.
  /// - Throws: An error if the underlying database read fails.
  public func indexedReleasesByPlatform(source: Source.ID) async throws
    -> [ApplePlatform: [SemanticVersion]]
  {
    try await store.indexedReleasesByPlatform(source: source)
  }

  /// Returns frameworks in `source`'s index with API new in any of the given
  /// releases, each with its new-symbol count.
  ///
  /// - Parameters:
  ///   - selections: The OS releases that count as new.
  ///   - source: The source whose index is read.
  /// - Returns: The frameworks with API new in the given releases, each with
  ///   its new-symbol count.
  /// - Throws: An error if the underlying database read fails.
  public func frameworksWithNewSymbols(
    for selections: [VersionSelection], source: Source.ID
  )
    async throws -> [FrameworkSummary]
  {
    try await store.frameworksWithNewSymbols(for: selections, source: source)
  }

  /// Returns every framework's module name in `source`'s index, sorted for
  /// display.
  ///
  /// - Parameter source: The source whose index is read.
  /// - Returns: Every framework's module name in `source`'s index, sorted
  ///   for display.
  /// - Throws: An error if the underlying database read fails.
  public func frameworkNames(source: Source.ID) async throws -> [String] {
    try await store.frameworkNames(source: source)
  }

  /// Returns the reconstructed index for one framework in `source`'s index,
  /// or `nil` when it has no symbols there.
  ///
  /// Reading a framework decodes all of its symbols, so a caller that queries
  /// the same framework repeatedly should cache the result.
  ///
  /// - Parameters:
  ///   - moduleName: The framework's module name.
  ///   - source: The source whose index is read.
  /// - Returns: The framework's reconstructed index, or `nil` when it has no
  ///   symbols in `source`'s index.
  /// - Throws: An error if the underlying database read fails.
  public func frameworkIndex(
    forModule moduleName: String, source: Source.ID
  ) async throws
    -> FrameworkIndex?
  {
    try await store.frameworkIndex(forModule: moduleName, source: source)
  }

  /// Returns the tree of symbols new for the given releases in a framework,
  /// filtered to the given kinds, read from `source`'s index.
  ///
  /// Building the tree costs the same as ``frameworkIndex(forModule:source:)``,
  /// so a caller needing both should call once and derive the other.
  ///
  /// - Parameters:
  ///   - moduleName: The framework's module name.
  ///   - source: The source whose index is read.
  ///   - selections: The OS releases that count as new.
  ///   - kinds: The symbol kinds to include, or `nil` to include every kind.
  /// - Returns: The tree of new symbols for the given releases, filtered to
  ///   the given kinds.
  /// - Throws: An error if the underlying database read fails.
  public func newSymbolTree(
    forModule moduleName: String,
    source: Source.ID,
    selections: [VersionSelection],
    kinds: Set<SymbolKind>? = nil
  ) async throws -> [SymbolTreeNode] {
    guard let index = try await store.frameworkIndex(
      forModule: moduleName, source: source
    )
    else { return [] }
    return index.newSymbolTree(for: selections, kinds: kinds)
  }

  /// Returns ranked search hits for the query in `source`'s index, filtered
  /// to symbols new for the given releases and to the given kinds.
  ///
  /// - Parameters:
  ///   - query: The search text to match.
  ///   - source: The source whose index is read.
  ///   - selections: The OS releases that count as new, or `nil` to include
  ///     every release.
  ///   - kinds: The symbol kinds to include, or `nil` to include every kind.
  ///   - limit: The maximum number of hits to return.
  /// - Returns: The ranked search hits for `query`.
  /// - Throws: An error if the underlying database read fails.
  public func search(
    _ query: String,
    source: Source.ID,
    selections: [VersionSelection]? = nil,
    kinds: Set<SymbolKind>? = nil,
    limit: Int = IndexStore.defaultSearchLimit
  ) async throws -> [SearchHit] {
    try await store.search(
      query: query, source: source, selections: selections, kinds: kinds,
      limit: limit
    )
  }

  /// Returns the diff of one framework between two sources' indexes.
  ///
  /// A module that one source does not index diffs against an empty
  /// snapshot, so all of its symbols count as added or removed.
  ///
  /// - Parameters:
  ///   - moduleName: The framework's module name.
  ///   - oldSource: The source whose index is the old snapshot.
  ///   - newSource: The source whose index is the new snapshot.
  /// - Returns: The framework's diff between the two sources' indexes.
  /// - Throws: An error if the underlying database read fails.
  public func frameworkDiff(
    forModule moduleName: String,
    from oldSource: Source.ID,
    to newSource: Source.ID
  ) async throws -> FrameworkDiff {
    try await store.frameworkDiff(
      forModule: moduleName, from: oldSource, to: newSource
    )
  }

  /// Returns each framework's diff counts between two sources' indexes,
  /// sorted by module name and without frameworks whose API is the same in
  /// both.
  ///
  /// - Parameters:
  ///   - oldSource: The source whose index is the old snapshot.
  ///   - newSource: The source whose index is the new snapshot.
  /// - Returns: Each changed framework's diff counts between the two
  ///   sources' indexes.
  /// - Throws: An error if the underlying database read fails.
  public func frameworkDiffSummaries(
    from oldSource: Source.ID, to newSource: Source.ID
  ) async throws -> [FrameworkDiffSummary] {
    try await store.frameworkDiffSummaries(from: oldSource, to: newSource)
  }

  /// Returns the symbol with the given USR in a framework in `source`'s
  /// index, or `nil` when it is not indexed there.
  ///
  /// Looking up one symbol costs the same as ``frameworkIndex(forModule:source:)``,
  /// so a caller resolving several USRs should fetch the index once.
  ///
  /// - Parameters:
  ///   - usr: The symbol's USR.
  ///   - moduleName: The framework's module name.
  ///   - source: The source whose index is read.
  /// - Returns: The symbol with the given USR, or `nil` when `source`'s
  ///   index does not contain it.
  /// - Throws: An error if the underlying database read fails.
  public func symbol(
    usr: String, inModule moduleName: String, source: Source.ID
  ) async throws
    -> IndexedSymbol?
  {
    guard let index = try await store.frameworkIndex(
      forModule: moduleName, source: source
    )
    else { return nil }
    return index.symbol(usr: usr)
  }
}
