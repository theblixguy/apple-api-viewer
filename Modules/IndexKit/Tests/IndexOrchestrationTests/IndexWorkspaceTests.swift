import CoreModel
import Dependencies
import DependenciesTestSupport
import Foundation
import IndexOrchestration
import IndexStore
import SymbolGraphIndex
import Testing

@Suite("Index workspace", .tags(.indexing))
struct IndexWorkspaceTests {
  @Test(
    "Deleting an index by source removes an orphaned index",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func deleteIndexBySourceRemovesAnOrphanedIndex() async throws {
    let store = IndexStore()
    let gone = xcodeInstallation("Xcode-old", build: "26A100")
    try await store.replaceIndex(
      signature: "sig-gone", source: .appleSDK(for: gone), frameworks: []
    )

    let workspace = IndexWorkspace(store: store)
    try await workspace.deleteIndex(
      forSource: Source.appleSDKID(forBuild: "26A100")
    )
    #expect(try await workspace.hasIndex(for: gone) == false)
  }

  @Test(
    "Deleting an index removes one Xcode's index",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func deleteIndexRemovesOneXcodesIndex() async throws {
    let store = IndexStore()
    let stable = xcodeInstallation("Xcode", build: "27A100")
    let beta = xcodeInstallation("Xcode-beta", build: "27B50")
    try await store.replaceIndex(
      signature: "a", source: .appleSDK(for: stable), frameworks: []
    )
    try await store.replaceIndex(
      signature: "b", source: .appleSDK(for: beta), frameworks: []
    )

    let workspace = IndexWorkspace(store: store)
    try await workspace.deleteIndex(for: stable)
    #expect(try await workspace.hasIndex(for: stable) == false)
    #expect(try await workspace.hasIndex(for: beta))
  }
}
