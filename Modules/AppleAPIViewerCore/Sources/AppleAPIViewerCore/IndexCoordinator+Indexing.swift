import CoreModel
import Foundation
import IndexOrchestration
import IndexStore

extension IndexCoordinator {
  /// Rebuilds the index across all installed SDKs.
  public func reindex() async {
    guard selectedMissingIndex == nil else { return }
    guard let xcode else { return await prepare() }
    await runIndexing(xcode: xcode)
  }

  /// Re-indexes a single module in place.
  ///
  /// - Parameter moduleName: The module to re-index.
  public func reindexModule(_ moduleName: String) async {
    guard selectedMissingIndex == nil, let xcode, !isMutatingIndex else {
      return
    }
    reindexError = nil
    reindexingModule = moduleName
    defer { reindexingModule = nil }
    do {
      let replaced = try await workspace.reindexModule(moduleName, for: xcode)
      if !replaced {
        reindexError = String(
          localized: "\(moduleName) isn't in the selected Xcode's SDKs."
        )
      }
    } catch {
      reindexError = error.localizedDescription
    }
  }

  /// Dismisses the last re-index error.
  public func clearReindexError() {
    reindexError = nil
  }

  /// Re-checks whether the index is still current, without disrupting
  /// browsing. The index can go stale, for example when the user
  /// downloads an SDK while the app is open. Call this method when the
  /// app becomes active.
  public func checkForChanges() async {
    guard selectedMissingIndex == nil, case .ready = status, let xcode else {
      return
    }
    let upToDate = (try? await workspace.isIndexUpToDate(for: xcode)) ?? true
    hasPendingChanges = !upToDate
  }

  /// Cancels an in-progress full index build.
  ///
  /// In-flight module extractions finish, then the build stops without replacing
  /// the stored index.
  public func cancelIndexing() {
    guard case .indexing = status else { return }
    isPaused = false
    status = .canceling
    indexingTask?.cancel()
  }

  /// Pauses the in-progress build. No new module starts while paused.
  ///
  /// In-flight extractions finish and the build waits until it is resumed.
  public func pauseIndexing() {
    guard case .indexing = status, !isPaused else { return }
    setPaused(true)
  }

  /// Resumes a paused build.
  public func resumeIndexing() {
    guard isPaused else { return }
    setPaused(false)
  }

  // MARK: - Internal

  func stopIndexing() async {
    guard let existing = indexingTask else { return }
    indexingTask = nil
    indexingGeneration += 1
    existing.cancel()
    _ = try? await existing.value
    pauseUpdate?.cancel()
    pauseUpdate = nil
    pauseController = nil
    isPaused = false
  }

  func runIndexing(xcode: XcodeInstallation) async {
    await stopIndexing()

    indexingGeneration += 1
    let generation = indexingGeneration

    hasPendingChanges = false
    isPaused = false
    let pause = PauseController()
    pauseController = pause
    status = .indexing(
      IndexingProgress(completed: 0, total: 0, currentModule: nil)
    )

    let task = Task { @concurrent [workspace] in
      try await workspace.buildIndex(for: xcode) {
        [weak self, pause] progress in
        await self?.updateIndexingProgress(progress)
        await pause.waitWhilePaused()
      }
    }
    indexingTask = task

    do {
      try await task.value
      guard indexingGeneration == generation else { return }
      indexingTask = nil
      status = .ready
    } catch is CancellationError {
      guard indexingGeneration == generation else { return }
      indexingTask = nil
      let upToDate = (try? await workspace.isIndexUpToDate(for: xcode)) ?? false
      status = upToDate ? .ready : .needsIndexing
    } catch {
      guard indexingGeneration == generation else { return }
      indexingTask = nil
      status = .failed(error.localizedDescription)
    }
    await refreshIndexedSources()
  }

  // MARK: - Private

  private func setPaused(_ paused: Bool) {
    isPaused = paused
    let controller = pauseController
    let previous = pauseUpdate
    pauseUpdate = Task { @concurrent in
      await previous?.value
      if paused {
        await controller?.pause()
      } else {
        await controller?.resume()
      }
    }
  }

  private func updateIndexingProgress(_ progress: IndexingProgress) {
    guard case .indexing = status else { return }
    status = .indexing(progress)
  }
}
