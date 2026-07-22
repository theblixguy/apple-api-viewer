import CoreModel
import Foundation
import IndexingService
import IndexStore

/// The UI-free entry point for managing the index.
///
/// ``XcodeRegistry`` chooses which Xcode the index builds from.
public struct IndexWorkspace: Sendable {
  private let store: IndexStore
  private let databaseURL: URL?

  /// Creates a workspace backed by the given store.
  ///
  /// - Parameters:
  ///   - store: The index store to read and write.
  ///   - databaseURL: The on-disk database file the store opened, or `nil`
  ///     for an in-memory store. A full build takes a cross-process lock
  ///     beside this file.
  public init(store: IndexStore, databaseURL: URL? = nil) {
    self.store = store
    self.databaseURL = databaseURL
  }

  private func service(for xcode: XcodeInstallation) -> IndexingService {
    IndexingService(xcode: xcode, store: store)
  }

  /// Returns a Boolean value that indicates whether the stored index matches
  /// `xcode`'s current toolchain and SDKs.
  ///
  /// - Parameter xcode: The Xcode installation to compare against the stored
  ///   index.
  /// - Returns: `true` when the stored index matches `xcode`'s current
  ///   toolchain and SDKs.
  /// - Throws: An error if the underlying database read fails.
  public func isIndexUpToDate(for xcode: XcodeInstallation) async throws -> Bool
  {
    try await service(for: xcode).isIndexUpToDate()
  }

  /// Builds or rebuilds the whole index from `xcode`'s SDKs.
  ///
  /// The `progress` closure is called as each module finishes, then once more
  /// with a saving phase before the final commit. A build on an on-disk
  /// database holds a cross-process lock, so one build runs at a time.
  ///
  /// - Parameters:
  ///   - xcode: The Xcode installation to build the index from.
  ///   - progress: A closure that reports each module's completion.
  /// - Throws: `CancellationError` if the task is canceled, which stops the
  ///   build without replacing the stored index,
  ///   ``IndexBuildInProgressError`` when another process is already
  ///   building, or an error from extraction or the store write.
  public func buildIndex(
    for xcode: XcodeInstallation,
    progress: @Sendable @escaping (IndexingProgress) async -> Void = { _ in }
  ) async throws {
    guard let databaseURL else {
      return try await service(for: xcode).buildIndex(progress: progress)
    }
    let lock = try IndexBuildLock(databaseURL: databaseURL)
    try await service(for: xcode).buildIndex(progress: progress)
    lock.release()
  }

  /// Re-extracts a single module from `xcode` and replaces just that framework.
  ///
  /// - Parameters:
  ///   - moduleName: The module to re-extract.
  ///   - xcode: The Xcode installation to extract the module from.
  /// - Returns: Whether the module was found and replaced. `false` means no
  ///   SDK provides it and the stored index is unchanged.
  /// - Throws: An error when extraction fails, so a failed re-index is never
  ///   mistaken for the module being absent.
  @discardableResult
  public func reindexModule(_ moduleName: String, for xcode: XcodeInstallation)
    async throws -> Bool
  {
    try await service(for: xcode).indexModule(moduleName)
  }

  /// Returns a Boolean value that indicates whether `xcode`'s index exists in
  /// the store, current or stale.
  ///
  /// - Parameter xcode: The Xcode installation whose index presence to check.
  /// - Returns: `true` when the store holds an index for `xcode`, current or
  ///   stale.
  /// - Throws: An error if the underlying database read fails.
  public func hasIndex(for xcode: XcodeInstallation) async throws -> Bool {
    try await store.signature(forSource: Source.appleSDK(for: xcode).id) != nil
  }

  /// Returns every source's index with its recorded signature and footprint.
  ///
  /// - Returns: Every source's index, with its recorded signature and
  ///   footprint.
  /// - Throws: An error if the underlying database read fails.
  public func indexedSources() async throws -> [IndexedSource] {
    try await store.indexedSources()
  }

  /// Deletes one Xcode's index and returns the freed space to the file system.
  ///
  /// Deleting rebuilds the database file to reclaim space, which can be slow
  /// for a large index.
  ///
  /// - Parameter xcode: The Xcode installation whose index to delete.
  /// - Throws: An error if the underlying database write fails.
  public func deleteIndex(for xcode: XcodeInstallation) async throws {
    try await deleteIndex(forSource: Source.appleSDK(for: xcode).id)
  }

  /// Deletes one source's index and returns the freed space to the file
  /// system, for indexes whose Xcode no longer resolves.
  ///
  /// Deleting rebuilds the database file to reclaim space, which can be slow
  /// for a large index.
  ///
  /// - Parameter source: The source whose index to delete.
  /// - Throws: An error if the underlying database write fails.
  public func deleteIndex(forSource source: Source.ID) async throws {
    try await store.removeSource(source)
    try await store.compact()
  }

  /// Deletes every source's index and returns the freed space to the file
  /// system.
  ///
  /// Deleting rebuilds the database file to reclaim space, which can be slow
  /// for a large index.
  ///
  /// - Returns: `true` when at least one index existed.
  /// - Throws: An error if the underlying database write fails.
  public func deleteAllIndexes() async throws -> Bool {
    let removed = try await store.removeAllSources()
    try await store.compact()
    return removed
  }
}
