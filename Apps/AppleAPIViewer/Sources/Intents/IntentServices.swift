import AppleAPIViewerCore
import CoreModel
import Dependencies
import Foundation
import IndexOrchestration
import IndexStore
import SymbolGraphIndex

// Read-only intents resolve their own source instead of waiting for the
// coordinator. A background intent launch can run before the UI prepares
// the coordinator.
@MainActor
final class IntentServices {
  let coordinator: IndexCoordinator
  let browser: BrowserModel
  let query: SymbolQuery

  @Dependency(\.xcodeRegistry) private var registry

  nonisolated init(
    coordinator: IndexCoordinator, browser: BrowserModel, store: IndexStore
  ) {
    self.coordinator = coordinator
    self.browser = browser
    query = SymbolQuery(store: store)
  }

  func resolveSource() async -> Source.ID? {
    if let id = coordinator.activeSourceID { return id }
    guard let xcode = await registry.activeXcode() else { return nil }
    return Source.appleSDK(for: xcode).id
  }

  func newestReleases(source: Source.ID) async throws -> [VersionSelection] {
    let releases = try await query.indexedReleasesByPlatform(source: source)
    return releases.compactMap { platform, versions in
      versions.first { !$0.isUnversioned }.map {
        VersionSelection(platform: platform, version: $0)
      }
    }
    .sorted { $0.platform < $1.platform }
  }
}
