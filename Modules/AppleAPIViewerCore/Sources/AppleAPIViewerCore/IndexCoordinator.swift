import CoreModel
import Dependencies
import Foundation
import IndexOrchestration
import IndexStore
import Observation

/// Owns the index lifecycle, from discovering Xcode to building the index.
@MainActor
@Observable
public final class IndexCoordinator {
  /// The stage of the index lifecycle.
  public enum Status: Sendable, Equatable {
    /// The coordinator resolves the toolchain and checks whether the index
    /// is current.
    case preparing
    /// No current index exists and automatic indexing is off.
    case needsIndexing
    /// A full build is running, with its latest progress.
    case indexing(IndexingProgress)
    /// A canceled build is finishing its in-flight modules.
    case canceling
    /// The index is current and browsable.
    case ready
    /// The lifecycle stopped for the contained reason.
    case failed(String)
  }

  /// The current stage of the index lifecycle.
  public internal(set) var status: Status = .preparing

  /// The Xcode currently being indexed from.
  public internal(set) var xcode: XcodeInstallation?

  /// The source identifier the app browses. Every read uses this scope. The
  /// value is the active Xcode's index, or a selected stored index whose
  /// Xcode is gone.
  public var activeSourceID: Source.ID? {
    selectedMissingIndex ?? xcode.map { Source.appleSDK(for: $0).id }
  }

  /// The stored index the app browses although its Xcode no longer
  /// resolves, or `nil`. Browsing such an index is read-only. Re-indexing
  /// needs the Xcode.
  public internal(set) var selectedMissingIndex: Source.ID?

  /// Stored indexes whose Xcode is no longer in the registry. They stay
  /// browsable until the user deletes them.
  public var missingIndexes: [IndexedSource] {
    let knownIDs = Set(availableXcodes.map { Source.appleSDK(for: $0).id })
    return indexedSources.filter {
      $0.source.kind == .appleSDK && !knownIDs.contains($0.id)
    }
  }

  /// Every stored index with its recorded signature and footprint, for the
  /// settings list.
  public internal(set) var indexedSources: [IndexedSource] = []

  /// A Boolean value that indicates whether the index follows the
  /// `xcode-select` Xcode rather than a pinned choice.
  public internal(set) var isFollowingSystemXcode = false

  /// The valid managed Xcodes, newest first.
  public internal(set) var availableXcodes: [XcodeInstallation] = []

  /// Every managed Xcode for the settings list, including any that no longer
  /// resolve, with broken entries last.
  public internal(set) var xcodeEntries: [XcodeEntry] = []

  /// A Boolean value that indicates whether the installed SDKs or Xcode
  /// changed since the index was built.
  public internal(set) var hasPendingChanges = false

  /// The module name while a single-module re-index runs in place, or `nil`.
  public internal(set) var reindexingModule: String?

  /// The message from the last failed in-place re-index.
  public internal(set) var reindexError: String?

  @ObservationIgnored var indexingTask: Task<Void, Error>?

  @ObservationIgnored var pauseController: PauseController?

  // Rapid pause and resume toggles must reach the controller in order.
  @ObservationIgnored var pauseUpdate: Task<Void, Never>?

  /// A Boolean value that indicates whether the in-progress build is
  /// paused.
  public internal(set) var isPaused = false

  // A stale callback must not overwrite the state of the build that
  // replaced it. `Task` is a value type and does not support identity
  // comparison, so a counter identifies the current build.
  @ObservationIgnored var indexingGeneration = 0

  /// The index database the coordinator reads from and rebuilds.
  public let store: IndexStore

  // The CLI shares this workspace, so a behavior change here reaches both
  // front ends.
  let workspace: IndexWorkspace

  // The CLI reads the same registry, so a change here reaches both front
  // ends.
  @ObservationIgnored @Dependency(\.xcodeRegistry) var registry

  static let noXcodeMessage = String(
    localized:
    "No Xcode found in /Applications. Install Xcode, or add one in Settings > Xcodes."
  )

  /// How the index database was opened. `.inMemoryFallback` means the saved
  /// index could not be loaded. This session's index does not persist.
  public let storageMode: IndexStore.StorageMode

  /// Creates a coordinator over the given index store and storage mode.
  ///
  /// - Parameters:
  ///   - store: The index store to browse and rebuild.
  ///   - storageMode: How the index database was opened.
  ///   - databaseURL: The on-disk database file, or `nil` for an in-memory
  ///     store. A full build takes a cross-process lock beside this file.
  public init(
    store: IndexStore, storageMode: IndexStore.StorageMode = .persistent,
    databaseURL: URL? = nil
  ) {
    self.store = store
    workspace = IndexWorkspace(store: store, databaseURL: databaseURL)
    self.storageMode = storageMode
  }

  deinit {
    indexingTask?.cancel()
    pauseUpdate?.cancel()
  }

  /// A Boolean value that indicates whether a full build or a
  /// single-module re-index is currently running. Callers use it to
  /// prevent index-mutating operations from overlapping.
  public var isMutatingIndex: Bool {
    if case .indexing = status { return true }
    if case .canceling = status { return true }
    return reindexingModule != nil
  }

  /// Resolves the toolchain and brings the index up to date. When
  /// `autoIndex` is `true`, its default, the coordinator rebuilds a stale
  /// or missing index immediately.
  ///
  /// - Parameter autoIndex: A Boolean value that indicates whether to
  ///   rebuild a stale or missing index automatically.
  public func prepare(autoIndex: Bool = true) async {
    // A window reopen re-runs the scene task that calls this method.
    // Without this guard, that would cancel a running build and restart
    // it from zero.
    guard !isMutatingIndex else { return }
    status = .preparing
    await refreshXcodeState()

    var candidate = xcode
    if candidate == nil {
      candidate = await registry.activeXcode()
    }
    guard let chosen = candidate else {
      status = .failed(Self.noXcodeMessage)
      return
    }
    xcode = chosen

    do {
      if try await workspace.isIndexUpToDate(for: chosen) {
        status = .ready
      } else if autoIndex {
        // A second caller can start a build while this one reads the
        // stored signature.
        guard !isMutatingIndex else { return }
        await runIndexing(xcode: chosen)
      } else {
        status = .needsIndexing
      }
    } catch {
      status = .failed(error.localizedDescription)
    }
  }

  /// Returns the stored index summary for a settings entry.
  ///
  /// - Parameter entry: The registry entry to look up.
  /// - Returns: The stored index summary, or `nil` when that Xcode has no
  ///   index.
  public func indexedSource(for entry: XcodeEntry) -> IndexedSource? {
    guard let installation = entry.installation else { return nil }
    let id = Source.appleSDK(for: installation).id
    return indexedSources.first { $0.id == id }
  }
}
