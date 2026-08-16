import CoreModel
import IndexStore
import SymbolGraphIndex

extension BrowserModel {
  /// A Boolean value that indicates whether the browser compares the active
  /// index against an older one.
  public var isComparing: Bool { comparisonSource != nil }

  /// Starts comparing the active index against `source`'s index.
  ///
  /// Comparing a source against itself does nothing.
  ///
  /// - Parameter source: The source whose index is the old snapshot.
  public func compare(against source: Source) {
    guard source.id != activeSource, source.id != comparisonSource else {
      return
    }
    comparisonSource = source.id
    comparisonDisplayName = source.displayName
    selectedDiffModule = nil
    selectedDiffEntry = nil
    focusedDiff = nil
    diffCache.removeAll()
  }

  /// Stops comparing and returns to browsing the active index.
  public func stopComparing() {
    comparisonSource = nil
    comparisonDisplayName = nil
    selectedDiffModule = nil
    selectedDiffEntry = nil
    focusedDiff = nil
    diffCache.removeAll()
  }

  /// Returns the indexed sources the active index can compare against.
  ///
  /// - Returns: Every built index in the store except the active one.
  public func comparisonCandidates() async -> [IndexedSource] {
    guard let activeSource else { return [] }
    let sources = await read { try await store.indexedSources() } ?? []
    return sources.filter { $0.id != activeSource && $0.signature != nil }
  }

  /// Returns each framework's diff counts between the compared indexes.
  ///
  /// - Returns: Each changed framework's diff counts, an empty array when
  ///   the browser is not comparing, or `nil` if the read was canceled or
  ///   failed.
  public func diffSummaries() async -> [FrameworkDiffSummary]? {
    guard let activeSource, let comparisonSource else { return [] }
    return await read {
      try await query.frameworkDiffSummaries(
        from: comparisonSource, to: activeSource
      )
    }
  }

  /// Returns one framework's diff between the compared indexes, shaped as
  /// trees for display.
  ///
  /// - Parameter moduleName: The framework's module name.
  /// - Returns: The framework's diff trees, or `nil` when the browser is
  ///   not comparing or the read was canceled or failed.
  public func diffTrees(forModule moduleName: String) async
    -> FrameworkDiffTrees?
  {
    if let cached = diffCache[moduleName] { return cached }
    guard let activeSource, let comparisonSource else { return nil }
    let revision = dataRevision
    let oldSource = comparisonSource
    let newSource = activeSource
    // The inner optional distinguishes a module one source does not index,
    // which diffs against an empty snapshot, from a failed read, which
    // must not produce an all-removed or all-added diff.
    guard case let .some(oldIndex) = await read({
      try await query.frameworkIndex(forModule: moduleName, source: oldSource)
    }),
      case let .some(newIndex) = await read({
        try await query.frameworkIndex(
          forModule: moduleName, source: newSource
        )
      })
    else {
      return nil
    }

    let empty = FrameworkIndex(moduleName: moduleName, symbols: [])
    let trees = await Self.makeDiffTrees(
      from: oldIndex ?? empty, to: newIndex ?? empty
    )
    // A read that starts before a re-index commit or a source switch can
    // finish after the cache was cleared. Without this check, its result
    // would repopulate the cache with the old data.
    if !Task.isCancelled, revision == dataRevision,
       oldSource == comparisonSource, newSource == activeSource
    {
      diffCache[moduleName] = trees
    }
    return trees
  }

  @concurrent
  private nonisolated static func makeDiffTrees(
    from old: FrameworkIndex, to new: FrameworkIndex
  ) async -> FrameworkDiffTrees {
    FrameworkDiffTrees(from: old, to: new)
  }
}
