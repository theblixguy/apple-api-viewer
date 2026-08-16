import CoreModel
import Dependencies
import DependenciesTestSupport
import SymbolGraphIndex
import Testing
import TestSupport
@testable import IndexStore

@Suite("Index store diffing", .tags(.storage, .diffing))
struct IndexStoreDiffingTests {
  @Test(
    "Diff summaries cover changed, all-added, and all-removed modules",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func summarizesModulesAcrossTwoSources() async throws {
    let store = try await Self.populatedStore()

    let summaries = try await store.frameworkDiffSummaries(
      from: Self.oldSDK.id, to: Self.newSDK.id
    )

    #expect(summaries.map(\.moduleName) == ["Arrived", "PencilKit", "Retired"])
    let arrived = try #require(summaries.first { $0.moduleName == "Arrived" })
    #expect(arrived.addedCount == 1)
    #expect(arrived.removedCount == 0)
    let retired = try #require(summaries.first { $0.moduleName == "Retired" })
    #expect(retired.addedCount == 0)
    #expect(retired.removedCount == 1)
    let pencilKit = try #require(
      summaries.first { $0.moduleName == "PencilKit" }
    )
    #expect(pencilKit.addedCount == 1)
    #expect(pencilKit.removedCount == 1)
    #expect(pencilKit.changedCount == 1)
  }

  @Test(
    "Diff summaries omit a module with the same API in both sources",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func omitsUnchangedModules() async throws {
    let store = try await Self.populatedStore()

    let summaries = try await store.frameworkDiffSummaries(
      from: Self.oldSDK.id, to: Self.newSDK.id
    )

    #expect(!summaries.contains { $0.moduleName == "Stable" })
  }

  @Test(
    "The framework diff resolves symbols from both sources",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func diffsOneFrameworkAcrossTwoSources() async throws {
    let store = try await Self.populatedStore()

    let diff = try await store.frameworkDiff(
      forModule: "PencilKit", from: Self.oldSDK.id, to: Self.newSDK.id
    )

    #expect(diff.added.map(\.usr) == ["s:PKAdded"])
    #expect(diff.removed.map(\.usr) == ["s:PKRemoved"])
    #expect(diff.changed.map(\.id) == ["s:PKFlipped"])
    #expect(diff.changed.first?.reasons == [.deprecation])
  }

  @Test(
    "A module unknown to both sources diffs as empty",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func diffsUnknownModuleAsEmpty() async throws {
    let store = try await Self.populatedStore()

    let diff = try await store.frameworkDiff(
      forModule: "Missing", from: Self.oldSDK.id, to: Self.newSDK.id
    )

    #expect(diff.isEmpty)
    #expect(diff.moduleName == "Missing")
  }

  // MARK: - Fixtures

  static let oldSDK = Source(
    id: "apple-sdk:26A1", kind: .appleSDK, displayName: "Xcode 26.0"
  )
  static let newSDK = Source(
    id: "apple-sdk:27A1", kind: .appleSDK, displayName: "Xcode 27.0"
  )

  private static func populatedStore() async throws -> IndexStore {
    let store = IndexStore()
    let stable = FrameworkIndex(
      moduleName: "Stable",
      symbols: [
        symbol(usr: "s:Stable", path: ["StableType"]),
      ]
    )
    try await store.replaceIndex(
      bySource: [
        oldSDK: [
          stable,
          FrameworkIndex(
            moduleName: "PencilKit",
            symbols: [
              symbol(usr: "s:PKKept", path: ["PKKept"]),
              symbol(usr: "s:PKRemoved", path: ["PKRemoved"]),
              symbol(usr: "s:PKFlipped", path: ["PKFlipped"]),
            ]
          ),
          FrameworkIndex(
            moduleName: "Retired",
            symbols: [symbol(usr: "s:Gone", path: ["Gone"])]
          ),
        ],
        newSDK: [
          stable,
          FrameworkIndex(
            moduleName: "PencilKit",
            symbols: [
              symbol(usr: "s:PKKept", path: ["PKKept"]),
              symbol(usr: "s:PKAdded", path: ["PKAdded"]),
              symbol(usr: "s:PKFlipped", path: ["PKFlipped"], deprecated: true),
            ]
          ),
          FrameworkIndex(
            moduleName: "Arrived",
            symbols: [symbol(usr: "s:Fresh", path: ["Fresh"])]
          ),
        ],
      ],
      signatures: [
        oldSDK.id: "26A1|iphoneos26.0",
        newSDK.id: "27A1|iphoneos27.0",
      ]
    )
    return store
  }

  private static func symbol(
    usr: String, path: [String], deprecated: Bool = false
  ) -> IndexedSymbol {
    IndexedSymbol(
      usr: usr,
      title: path.joined(separator: "."),
      kind: .structure,
      pathComponents: path,
      parentUSR: nil,
      introduced: iOS(26),
      isDeprecated: deprecated
    )
  }
}
