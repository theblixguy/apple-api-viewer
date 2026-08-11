import AsyncAlgorithms
import CoreModel
import Dependencies
import DocURLMapping
import Foundation
import IndexOrchestration
import IndexStore
import Observation
import SymbolGraphIndex

/// Drives browsing and search over a populated index.
///
/// Holds the user's selection state, such as which OS releases to show and
/// what is selected in each column. Views load query results with
/// `.task(id:)`. The model caches reconstructed framework indexes and
/// invalidates them on re-index.
@MainActor
@Observable
public final class BrowserModel {
  /// The populated index this model browses.
  public let store: IndexStore
  let query: SymbolQuery

  @ObservationIgnored
  @Dependency(\.continuousClock) var clock

  /// Every platform the app can show. Platforms not in ``indexedPlatforms``
  /// have no data in the index.
  public let supportedPlatforms = ApplePlatform.allCases

  /// Platforms present in the built index.
  public internal(set) var indexedPlatforms: [ApplePlatform] = []

  /// The source every read uses. It is one Xcode installation's index.
  ///
  /// Changing it invalidates the cached framework indexes and bumps
  /// ``dataRevision``.
  public var activeSource: Source.ID? {
    didSet {
      guard oldValue != activeSource else { return }
      // Without this, switching to the compared Xcode would diff an index
      // against itself.
      if comparisonSource == activeSource { stopComparing() }
      bumpDataRevision()
    }
  }

  /// The source whose index is the old snapshot in compare mode, or `nil`
  /// when the browser is not comparing.
  ///
  /// ``compare(against:)`` and ``stopComparing()`` set it.
  public internal(set) var comparisonSource: Source.ID?

  /// The compared source's display name, for labels.
  public internal(set) var comparisonDisplayName: String?

  /// The framework selected in the sidebar in compare mode.
  ///
  /// Changing the value clears ``selectedDiffEntry``.
  public var selectedDiffModule: String? {
    didSet {
      guard oldValue != selectedDiffModule else { return }
      selectedDiffEntry = nil
    }
  }

  /// The row selected in the compare list.
  public var selectedDiffEntry: DiffEntry?

  /// Each indexed platform's selectable OS releases, newest first.
  public internal(set) var releasesByPlatform:
    [ApplePlatform: [SemanticVersion]] = [:]

  /// Returns a Boolean value that indicates whether a supported platform has
  /// data in the index. A platform has data when its SDK is installed and
  /// indexed.
  ///
  /// - Parameter platform: The platform to check.
  /// - Returns: `true` when the platform has data in the index.
  public func isIndexed(_ platform: ApplePlatform) -> Bool {
    indexedPlatforms.contains(platform)
  }

  /// The chosen OS releases per platform, the active filter.
  public var chosenReleases: [ApplePlatform: Set<SemanticVersion>] = [:] {
    didSet { selections = Self.makeSelections(from: chosenReleases) }
  }

  // The property is stored, not computed. A computed property would
  // re-sort on every view update.
  /// The active filters as a sorted list.
  ///
  /// The value stays a stable `.task(id:)` key across view updates.
  public private(set) var selections: [VersionSelection] = []

  /// A counter that increases by one after each re-index.
  public internal(set) var dataRevision = 0

  /// The message from the last failed store read, or `nil` if the last read
  /// succeeded.
  public internal(set) var loadError: String?

  /// The framework selected in the sidebar.
  ///
  /// Changing the value clears ``selectedSymbol``.
  public var selectedFramework: FrameworkPick? {
    didSet {
      guard oldValue != selectedFramework else { return }
      selectedSymbol = nil
    }
  }

  /// The symbol selected in the tree or search results.
  public var selectedSymbol: SymbolReference?
  /// The current global-search query.
  public var searchText: String = ""
  /// A Boolean value that indicates whether the search field is active.
  /// Menu commands and App Intents set it to open search.
  public var searchPresented = false

  /// The symbol kinds to show in the tree and search. Empty means no filter.
  public var selectedKinds: Set<SymbolKind> = []

  /// Debounced search results for the current query, published by
  /// ``runSearch()``.
  public internal(set) var searchHits: [SearchHit] = []

  // A version or kind filter change reuses the cache instead of re-reading
  // and re-decoding the framework.
  @ObservationIgnored var frameworkIndexCache: [String: FrameworkIndex] = [:]

  // A selection change in the compare list reuses the cache instead of
  // re-diffing the framework.
  @ObservationIgnored var diffCache: [String: FrameworkDiff] = [:]

  /// A trimmed query shorter than this does not trigger a search.
  public static let minimumSearchLength = 2

  static let searchDebounce: Duration = .milliseconds(250)

  static let maximumInlineVersionLabels = 2

  /// Creates a browser over a populated index store.
  ///
  /// - Parameter store: The populated index store to browse.
  public init(store: IndexStore) {
    self.store = store
    query = SymbolQuery(store: store)
  }
}
