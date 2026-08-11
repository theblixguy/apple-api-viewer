import CoreModel
import Dependencies
import DependenciesTestSupport
import IndexOrchestration
import IndexStore
import SymbolGraphIndex
import Testing
import TestSupport

@Suite("Symbol query", .tags(.search, .symbolTree))
struct SymbolQueryTests {
  @Test(
    "The query lists frameworks with new symbols",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func listsFrameworksWithNewSymbols() async throws {
    let query = try await Self.populatedQuery()
    let frameworks = try await query.frameworksWithNewSymbols(
      for: Self.new27, source: sdk.id
    )
    #expect(frameworks.contains { $0.moduleName == "PencilKit" })
  }

  @Test(
    "Search applies a kind filter",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func searchAppliesKindFilter() async throws {
    let query = try await Self.populatedQuery()

    let all = try await query.search("Render", source: sdk.id)
    #expect(all.contains { $0.kind == .structure })
    #expect(all.contains { $0.kind == .property })

    let propertiesOnly = try await query.search(
      "Render", source: sdk.id, kinds: [.property]
    )
    #expect(!propertiesOnly.isEmpty)
    #expect(propertiesOnly.allSatisfy { $0.kind == .property })
  }

  @Test(
    "The new symbol tree nests matches under ancestors",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func newSymbolTreeNestsMatchesUnderAncestors() async throws {
    let query = try await Self.populatedQuery()
    let tree = try await query.newSymbolTree(
      forModule: "PencilKit", source: sdk.id, selections: Self.new27
    )
    let pkStroke = try #require(tree.first { $0.symbol.title == "PKStroke" })
    #expect(!pkStroke.isMatch)
    #expect(pkStroke.containsMatch)
  }

  @Test(
    "The new symbol tree is empty for an unknown module",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func newSymbolTreeIsEmptyForUnknownModule() async throws {
    let query = try await Self.populatedQuery()
    let tree = try await query.newSymbolTree(
      forModule: "Nope", source: sdk.id, selections: Self.new27
    )
    #expect(tree.isEmpty)
  }

  @Test(
    "A symbol resolves by USR",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func resolvesSymbolByUSR() async throws {
    let query = try await Self.populatedQuery()
    let symbol = try #require(
      try await query.symbol(
        usr: "s:RenderState", inModule: "PencilKit", source: sdk.id
      )
    )
    #expect(symbol.title == "PKStroke.RenderState")
  }

  @Test(
    "Resolving a symbol returns nil when absent",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func resolvesSymbolReturnsNilWhenAbsent() async throws {
    let query = try await Self.populatedQuery()
    #expect(
      try await query.symbol(
        usr: "s:nope", inModule: "PencilKit", source: sdk.id
      ) == nil
    )
    #expect(
      try await query.symbol(
        usr: "s:RenderState", inModule: "Nope", source: sdk.id
      ) == nil
    )
  }

  @Test(
    "The query diffs one framework between two sources",
    .tags(.diffing),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func diffsFrameworkBetweenTwoSources() async throws {
    let store = IndexStore()
    let older = Source(
      id: "apple-sdk:26A1", kind: .appleSDK, displayName: "Xcode 26.0"
    )
    try await store.replaceIndex(
      bySource: [
        older: [
          FrameworkIndex(moduleName: "PencilKit", symbols: []),
        ],
        sdk: [pencilKit()],
      ],
      signatures: [older.id: "26A1|iphoneos26.0", sdk.id: "27A|iphoneos27.0"]
    )
    let query = SymbolQuery(store: store)

    let diff = try await query.frameworkDiff(
      forModule: "PencilKit", from: older.id, to: sdk.id
    )
    let summaries = try await query.frameworkDiffSummaries(
      from: older.id, to: sdk.id
    )

    #expect(diff.added.count == pencilKit().symbols.count)
    #expect(diff.removed.isEmpty)
    #expect(summaries.map(\.moduleName) == ["PencilKit"])
    #expect(summaries.first?.addedCount == pencilKit().symbols.count)
  }

  // MARK: - Helpers

  static func populatedQuery() async throws -> SymbolQuery {
    let store = IndexStore()
    try await store.replaceIndex(
      signature: "27A|iphoneos27.0", source: sdk, frameworks: [pencilKit()]
    )
    return SymbolQuery(store: store)
  }

  static let new27 = [
    VersionSelection(platform: .iOS, version: SemanticVersion(major: 27)),
  ]
}
