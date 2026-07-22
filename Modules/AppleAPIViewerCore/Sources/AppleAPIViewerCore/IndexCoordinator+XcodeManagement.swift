import CoreModel
import Foundation
import IndexOrchestration
import IndexStore

extension IndexCoordinator {
  /// Chooses the Xcode the index builds from and remembers it as the default.
  ///
  /// The change reaches the stored index at the next rebuild. Picking an
  /// Xcode does not start a rebuild immediately.
  ///
  /// - Parameter xcode: The Xcode installation to build from.
  public func chooseDefaultXcode(_ xcode: XcodeInstallation) async {
    await setDefaultAndReconcile(applicationURL: xcode.applicationURL)
  }

  /// Adds an Xcode to the registry by its application bundle.
  ///
  /// - Parameter applicationURL: The Xcode application bundle to add.
  /// - Throws: ``XcodeRegistryError/notAnXcode(_:)`` when the bundle is not a
  ///   usable Xcode.
  public func addXcode(at applicationURL: URL) async throws(XcodeRegistryError)
  {
    try await registry.add(applicationURL: applicationURL)
    await refreshXcodeState()
  }

  /// Removes a manually added Xcode from the settings list, along with its
  /// stored index. Chooses a new default when the removed Xcode was active.
  ///
  /// - Parameter entry: The registry entry to remove. A broken entry's
  ///   index, if any, stays behind as a missing index. Its originating
  ///   build is unknown.
  public func removeXcode(_ entry: XcodeEntry) async {
    if let installation = entry.installation {
      try? await workspace.deleteIndex(for: installation)
    }
    registry.remove(applicationURL: entry.applicationURL)
    await refreshXcodeState()
    await reconcileActiveXcode()
  }

  /// Browses a stored index whose Xcode is gone, read-only.
  ///
  /// - Parameter index: The stored index to browse.
  public func browseMissingIndex(_ index: IndexedSource) async {
    guard selectedMissingIndex != index.id else { return }
    await stopIndexing()
    selectedMissingIndex = index.id
    hasPendingChanges = false
    status = .ready
  }

  /// Deletes a stored index whose Xcode is gone.
  ///
  /// Deleting the one being browsed returns to the active Xcode's index.
  ///
  /// - Parameter index: The stored index to delete.
  public func deleteMissingIndex(_ index: IndexedSource) async {
    guard !isMutatingIndex else { return }
    try? await workspace.deleteIndex(forSource: index.id)
    await refreshIndexedSources()
    guard selectedMissingIndex == index.id else { return }
    selectedMissingIndex = nil
    if let xcode {
      await adopt(xcode)
    } else {
      status = .failed(Self.noXcodeMessage)
    }
  }

  /// Chooses the default Xcode from the settings list.
  ///
  /// - Parameter entry: The registry entry to build from. A broken entry is
  ///   ignored.
  public func chooseDefaultXcode(_ entry: XcodeEntry) async {
    guard entry.installation != nil else { return }
    await setDefaultAndReconcile(applicationURL: entry.applicationURL)
  }

  /// Clears the chosen default. The index then follows the
  /// `xcode-select` Xcode.
  public func followSystemXcode() async {
    registry.clearDefault()
    await refreshXcodeState()
    await reconcileActiveXcode()
    await returnToActiveXcode()
  }

  /// Reloads the managed Xcodes from the registry. An Xcode installed
  /// while the app was open appears in the settings list after this call.
  public func refreshXcodes() async {
    await refreshXcodeState()
  }

  /// Deletes one Xcode's stored index.
  ///
  /// Deleting the index being browsed rebuilds it immediately. A broken
  /// entry is ignored. Pruning already removes indexes whose Xcode is
  /// gone.
  ///
  /// - Parameter entry: The registry entry whose index to delete.
  public func deleteIndex(for entry: XcodeEntry) async {
    guard let installation = entry.installation, !isMutatingIndex else {
      return
    }
    let sourceID = Source.appleSDK(for: installation).id
    try? await workspace.deleteIndex(for: installation)
    await refreshIndexedSources()
    if sourceID == activeSourceID {
      await runIndexing(xcode: installation)
    }
  }

  // MARK: - Internal

  func refreshXcodeState() async {
    xcodeEntries = await registry.entries()
    availableXcodes = xcodeEntries.compactMap(\.installation)
    isFollowingSystemXcode = !registry.hasPinnedDefault()
    await refreshIndexedSources()
  }

  func refreshIndexedSources() async {
    indexedSources = (try? await workspace.indexedSources()) ?? []
  }

  func adopt(_ active: XcodeInstallation) async {
    if (try? await workspace.isIndexUpToDate(for: active)) == true {
      hasPendingChanges = false
      status = .ready
    } else if (try? await workspace.hasIndex(for: active)) == true {
      status = .ready
      hasPendingChanges = true
    } else {
      hasPendingChanges = false
      await runIndexing(xcode: active)
    }
  }

  // MARK: - Private

  private func setDefaultAndReconcile(applicationURL: URL) async {
    try? registry.setDefault(applicationURL: applicationURL)
    await refreshXcodeState()
    await reconcileActiveXcode()
    await returnToActiveXcode()
  }

  private func reconcileActiveXcode() async {
    let active = await registry.activeXcode()
    guard active != xcode else { return }
    xcode = active
    await stopIndexing()
    selectedMissingIndex = nil
    guard let active else {
      status = .failed(Self.noXcodeMessage)
      return
    }
    await adopt(active)
  }

  private func returnToActiveXcode() async {
    guard selectedMissingIndex != nil else { return }
    selectedMissingIndex = nil
    if let xcode {
      await adopt(xcode)
    } else {
      status = .failed(Self.noXcodeMessage)
    }
  }
}
