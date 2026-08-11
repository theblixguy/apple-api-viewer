import AsyncAlgorithms
import CoreModel
import Dependencies
import Foundation
import IndexStore
import Observation
import SymbolGraphIndex

extension BrowserModel {
  /// Invalidates the cached framework indexes and increments
  /// ``dataRevision``. Call this after the store's contents change.
  public func bumpDataRevision() {
    frameworkIndexCache.removeAll()
    diffCache.removeAll()
    dataRevision += 1
  }

  /// Clears the current load error.
  public func dismissLoadError() {
    loadError = nil
  }

  func read<T>(_ work: () async throws -> T) async -> T? {
    do {
      let value = try await work()
      if loadError != nil { loadError = nil }
      return value
    } catch is CancellationError {
      return nil
    } catch {
      if Task.isCancelled { return nil }
      loadError = error.localizedDescription
      return nil
    }
  }

  /// A Boolean value that indicates whether the trimmed query is long
  /// enough to search.
  public var isSearching: Bool {
    searchText.trimmingCharacters(in: .whitespacesAndNewlines).count
      >= Self.minimumSearchLength
  }

  /// Loads the platform and version picker data. Drops selected releases
  /// that the active index does not contain. Seeds a default selection of
  /// the newest iOS and macOS releases when none remains.
  public func loadPickerData() async {
    guard let activeSource else {
      indexedPlatforms = []
      releasesByPlatform = [:]
      return
    }
    do {
      let releases = try await query.indexedReleasesByPlatform(
        source: activeSource
      )
      indexedPlatforms = ApplePlatform.allCases.filter {
        releases.keys.contains($0)
      }
      releasesByPlatform = releases

      var pruned: [ApplePlatform: Set<SemanticVersion>] = [:]
      for (platform, versions) in chosenReleases {
        let kept = versions.intersection(Set(releases[platform] ?? []))
        if !kept.isEmpty { pruned[platform] = kept }
      }
      if pruned != chosenReleases { chosenReleases = pruned }

      if chosenReleases.isEmpty {
        for platform in [ApplePlatform.iOS, .macOS] {
          if let newest = releases[platform]?
            .first(where: { !$0.isUnversioned })
          {
            chosenReleases[platform] = [newest]
          }
        }
      }
    } catch {
      indexedPlatforms = []
      releasesByPlatform = [:]
    }
  }

  /// Returns frameworks with API new in any of a platform's selected
  /// releases. The caller keeps its current list when the result is `nil`.
  ///
  /// - Parameter platform: The platform to return frameworks for.
  /// - Returns: The frameworks with new API, or `nil` if the read was
  ///   canceled or failed.
  public func frameworks(forPlatform platform: ApplePlatform) async
    -> [FrameworkSummary]?
  {
    guard let activeSource else { return [] }
    return await read {
      try await query.frameworksWithNewSymbols(
        for: selections(for: platform), source: activeSource
      )
    }
  }

  /// Returns the type and member tree for a framework, filtered to the
  /// active selection and kinds.
  ///
  /// - Parameter pick: The framework to return the tree for.
  /// - Returns: The type and member tree, or `nil` if the framework's index
  ///   is unavailable.
  public func tree(for pick: FrameworkPick) async -> [SymbolTreeNode]? {
    guard let index = await frameworkIndex(for: pick.moduleName) else {
      return nil
    }
    return await Self.makeTree(
      from: index, selections: selections(for: pick.platform), kinds: kindFilter
    )
  }

  /// Returns search hits for the current query, filtered to the active
  /// selection and kinds.
  ///
  /// - Returns: The search hits, an empty array when the query is not
  ///   active, or `nil` if the read was canceled or failed.
  public func searchResults() async -> [SearchHit]? {
    guard isSearching else { return [] }
    guard let activeSource else { return [] }
    let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return await read {
      try await query.search(
        text, source: activeSource, selections: selections, kinds: kindFilter
      )
    }
  }

  /// Watches the query inputs and keeps ``searchHits`` in sync until the
  /// calling task is canceled.
  ///
  /// The injected clock debounces bursts of change. A view starts this
  /// once and renders ``searchHits``.
  public func runSearch() async {
    // swiftformat:disable:next redundantSelf
    let debounceClock = AnyClock(self.clock)
    let inputs = Observations {
      SearchInputs(
        text: self.searchText, selections: self.selections,
        kinds: self.selectedKinds, revision: self.dataRevision,
        source: self.activeSource
      )
    }
    for await _ in inputs.debounce(
      for: Self.searchDebounce, clock: debounceClock
    ) {
      if let hits = await searchResults() { searchHits = hits }
    }
  }

  private struct SearchInputs: Sendable {
    let text: String
    let selections: [VersionSelection]
    let kinds: Set<SymbolKind>
    let revision: Int
    let source: Source.ID?
  }

  /// Returns the symbol referenced, resolved from its framework index.
  ///
  /// - Parameter reference: The symbol reference to resolve.
  /// - Returns: The resolved symbol, or `nil` if not found or if the read
  ///   was canceled or failed.
  public func resolveSymbol(_ reference: SymbolReference) async
    -> IndexedSymbol?
  {
    guard let index = await frameworkIndex(for: reference.moduleName) else {
      return nil
    }
    return await Self.symbol(usr: reference.usr, in: index)
  }

  private func frameworkIndex(for moduleName: String) async -> FrameworkIndex? {
    if let cached = frameworkIndexCache[moduleName] { return cached }
    guard let activeSource else { return nil }
    let revision = dataRevision
    let source = activeSource
    guard case let .some(.some(index)) = await read({
      try await query.frameworkIndex(forModule: moduleName, source: source)
    })
    else {
      return nil
    }
    // A read that starts before a re-index commit or a source switch can
    // finish after the cache was cleared. Without this check, its result
    // would repopulate the cache with the old data.
    if !Task.isCancelled, revision == dataRevision, source == activeSource {
      frameworkIndexCache[moduleName] = index
    }
    return index
  }

  @concurrent
  private nonisolated static func makeTree(
    from index: FrameworkIndex, selections: [VersionSelection],
    kinds: Set<SymbolKind>?
  ) async -> [SymbolTreeNode] {
    index.newSymbolTree(for: selections, kinds: kinds)
  }

  @concurrent
  private nonisolated static func symbol(
    usr: String, in index: FrameworkIndex
  ) async -> IndexedSymbol? {
    index.symbol(usr: usr)
  }
}
