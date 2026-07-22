import CoreModel
import Dependencies
import DependenciesTestSupport
import Foundation
import SymbolGraphIndex
import Testing
import TestSupport
@testable import IndexStore

@Suite("Index store", .tags(.storage))
struct IndexStoreTests {
  // MARK: - Metadata and listing

  @Test(
    "Framework name listing scopes to one source",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func listsFrameworkNamesScopedToOneSource() async throws {
    let store = try await Self.populatedStore()

    let names = try await store.frameworkNames(source: sdk.id)

    #expect(names == ["PencilKit", "SwiftUI"])
    #expect(try await store.frameworkNames(source: "apple-sdk:none").isEmpty)
  }

  @Test(
    "The store records the signature and framework names",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func recordsSignatureAndFrameworks() async throws {
    let store = try await Self.populatedStore()
    #expect(
      try await store.signature(forSource: sdk.id)
        == "27A5194q|iphoneos27.0,macosx27.0"
    )
    #expect(try await store.allFrameworkNames() == ["PencilKit", "SwiftUI"])
  }

  @Test(
    "The store records the source for indexed frameworks",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func recordsTheSourceForIndexedFrameworks() async throws {
    let store = try await Self.populatedStore()
    #expect(try await store.sources() == [sdk])
  }

  @Test(
    "Availability storage includes non-platform domains",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func storesGeneralAvailabilityIncludingNonPlatformDomains() async throws {
    let store = IndexStore()
    let symbol = IndexedSymbol(
      usr: "s:Widget", title: "Widget", kind: .structure,
      pathComponents: ["Widget"], parentUSR: nil,
      availability: [
        Availability(
          domain: .platform(.iOS), introduced: SemanticVersion(major: 27)
        ),
        Availability(
          domain: .package("swift-collections"),
          introduced: SemanticVersion(major: 1, minor: 2)
        ),
        Availability(domain: .package("private-lib"), introduced: nil),
      ],
      isDeprecated: false
    )
    try await store.replaceIndex(
      signature: "sig",
      source: sdk,
      frameworks: [FrameworkIndex(moduleName: "Widgets", symbols: [symbol])]
    )

    let readBack = try await store.frameworkIndex(
      forModule: "Widgets", source: sdk.id
    )?
      .symbols.first
    #expect(readBack?.availability.count == 3)
    #expect(readBack?.introduced[.iOS] == SemanticVersion(major: 27))
    #expect(
      readBack?.availability.contains(
        Availability(
          domain: .package("swift-collections"),
          introduced: SemanticVersion(major: 1, minor: 2)
        )
      )
        == true
    )
    #expect(
      readBack?.availability.contains(
        Availability(domain: .package("private-lib"), introduced: nil)
      ) == true
    )
  }

  @Test(
    "Replacing the index clears previous contents",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func replacingIndexClearsPreviousContents() async throws {
    let store = try await Self.populatedStore()
    try await store.replaceIndex(
      signature: "28A1|macosx27.0", source: sdk,
      frameworks: [Self.swiftUI()]
    )
    #expect(
      try await store.signature(forSource: sdk.id) == "28A1|macosx27.0"
    )
    #expect(try await store.allFrameworkNames() == ["SwiftUI"])
  }

  @Test(
    "Replacing a framework upserts only that module",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func replaceFrameworkUpsertsOneModuleOnly() async throws {
    let store = try await Self.populatedStore()
    let newPencilKit = FrameworkIndex(
      moduleName: "PencilKit",
      symbols: [
        IndexedSymbol(
          usr: "s:NewThing", title: "NewThing", kind: .class,
          pathComponents: ["NewThing"], parentUSR: nil,
          introduced: iOS(27), isDeprecated: false
        ),
      ]
    )
    try await store.replaceFramework(newPencilKit, source: sdk)

    #expect(
      try await store.signature(forSource: sdk.id)
        == "27A5194q|iphoneos27.0,macosx27.0"
    )
    #expect(try await store.allFrameworkNames() == ["PencilKit", "SwiftUI"])
    #expect(
      try await store.frameworkIndex(forModule: "SwiftUI", source: sdk.id)?
        .symbols.contains {
          $0.title == "View.glassEffect"
        } == true
    )

    #expect(
      try await store.frameworkIndex(
        forModule: "PencilKit", source: sdk.id
      )?.symbols.map(
        \.title
      ) == ["NewThing"]
    )
    #expect(
      try await store.search(query: "NewThing", source: sdk.id).contains {
        $0.usr == "s:NewThing"
      }
    )
    #expect(
      try await store.search(query: "Render", source: sdk.id).isEmpty
    )

    #expect(
      try await store.frameworksWithNewSymbols(
        for: [
          VersionSelection(platform: .iOS, version: SemanticVersion(major: 27)),
        ], source: sdk.id
      )
        == [FrameworkSummary(moduleName: "PencilKit", newSymbolCount: 1)]
    )
  }

  // MARK: - Version filtering

  @Test(
    "New symbol counts group by framework for a selection",
    .tags(.versioning),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func countsNewSymbolsPerFrameworkForSelection() async throws {
    let store = try await Self.populatedStore()
    let selection = [
      VersionSelection(platform: .iOS, version: SemanticVersion(major: 27)),
    ]
    #expect(
      try await store.frameworksWithNewSymbols(
        for: selection, source: sdk.id
      )
        == [FrameworkSummary(moduleName: "PencilKit", newSymbolCount: 2)]
    )
  }

  @Test(
    "Selections union across frameworks",
    .tags(.versioning),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func unionsSelectionsAcrossFrameworks() async throws {
    let store = try await Self.populatedStore()
    let selection = [
      VersionSelection(platform: .iOS, version: SemanticVersion(major: 26)),
    ]
    #expect(
      try await store.frameworksWithNewSymbols(
        for: selection, source: sdk.id
      ) == [
        FrameworkSummary(moduleName: "PencilKit", newSymbolCount: 1),
        FrameworkSummary(moduleName: "SwiftUI", newSymbolCount: 1),
      ]
    )
  }

  @Test(
    "New symbol counts stay distinct across platform selections",
    .tags(.versioning),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func countsDistinctSymbolsAcrossPlatformSelections() async throws {
    let store = try await Self.populatedStore()
    let selection = [
      VersionSelection(platform: .iOS, version: SemanticVersion(major: 27)),
      VersionSelection(platform: .macOS, version: SemanticVersion(major: 27)),
    ]
    #expect(
      try await store.frameworksWithNewSymbols(
        for: selection, source: sdk.id
      )
        == [FrameworkSummary(moduleName: "PencilKit", newSymbolCount: 2)]
    )
  }

  // MARK: - Tree reconstruction

  @Test(
    "The store reconstructs a framework index and its symbol tree",
    .tags(.symbolTree),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func reconstructsFrameworkIndexAndTree() async throws {
    let store = try await Self.populatedStore()
    let index = try #require(
      try await store.frameworkIndex(
        forModule: "PencilKit", source: sdk.id
      )
    )
    #expect(index.symbols.count == 4)

    let renderState = try #require(
      index.symbols.first { $0.title == "PKStroke.RenderState" }
    )
    #expect(renderState.parentUSR == "s:PKStroke")
    #expect(renderState.introduced[.macOS] == SemanticVersion(major: 27))
    #expect(renderState.summary == "The render details of a stroke.")

    let topLevel = try #require(index.symbols.first { $0.title == "PKStroke" })
    #expect(topLevel.summary == nil)
    #expect(topLevel.parentUSR == nil)

    let tree = index.newSymbolTree(for: [
      VersionSelection(platform: .iOS, version: SemanticVersion(major: 27)),
    ])
    let pkStroke = try #require(tree.first { $0.symbol.title == "PKStroke" })
    #expect(!pkStroke.isMatch)
    #expect(pkStroke.containsMatch)
    #expect(pkStroke.children.first?.symbol.title == "PKStroke.RenderState")
  }

  @Test(
    "Looking up an unknown framework returns nil",
    .tags(.symbolTree),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func returnsNilForUnknownFramework() async throws {
    let store = try await Self.populatedStore()
    #expect(
      try await store.frameworkIndex(forModule: "Nope", source: sdk.id)
        == nil
    )
  }

  // MARK: - Staged builds

  @Test(
    "A staged build keeps the live index until commit",
    .tags(.indexing),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func stagedBuildKeepsTheLiveIndexUntilCommit() async throws {
    let store = try await Self.populatedStore()
    try await store.beginStagedIndex()
    try await store.stageFramework(
      FrameworkIndex(
        moduleName: "WidgetKit",
        symbols: [
          IndexedSymbol(
            usr: "s:Widget", title: "Widget", kind: .protocol,
            pathComponents: ["Widget"], parentUSR: nil,
            introduced: iOS(27), isDeprecated: false
          ),
        ]
      ),
      source: sdk
    )

    #expect(try await store.allFrameworkNames() == ["PencilKit", "SwiftUI"])
    #expect(
      try await store.signature(forSource: sdk.id)
        == "27A5194q|iphoneos27.0,macosx27.0"
    )

    try await store.commitStagedIndex(
      signatures: [sdk.id: "staged-sig"]
    )
    #expect(try await store.allFrameworkNames() == ["WidgetKit"])
    #expect(try await store.signature(forSource: sdk.id) == "staged-sig")
    #expect(
      try await store.search(query: "Widget", source: sdk.id).contains {
        $0.usr == "s:Widget"
      }
    )
  }

  @Test(
    "Staging merges the same module by USR keeping the first",
    .tags(.indexing),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func stagingMergesTheSameModuleByUSRKeepingTheFirst() async throws {
    let store = IndexStore()
    try await store.beginStagedIndex()
    try await store.stageFramework(
      FrameworkIndex(
        moduleName: "PencilKit",
        symbols: [
          IndexedSymbol(
            usr: "s:Shared", title: "First", kind: .structure,
            pathComponents: ["First"], parentUSR: nil,
            introduced: iOS(27), isDeprecated: false
          ),
          IndexedSymbol(
            usr: "s:OnlyA", title: "OnlyA", kind: .structure,
            pathComponents: ["OnlyA"], parentUSR: nil,
            introduced: iOS(27), isDeprecated: false
          ),
        ]
      ),
      source: sdk
    )
    try await store.stageFramework(
      FrameworkIndex(
        moduleName: "PencilKit",
        symbols: [
          IndexedSymbol(
            usr: "s:Shared", title: "Second", kind: .structure,
            pathComponents: ["Second"], parentUSR: nil,
            introduced: iOS(27), isDeprecated: false
          ),
          IndexedSymbol(
            usr: "s:OnlyB", title: "OnlyB", kind: .structure,
            pathComponents: ["OnlyB"], parentUSR: nil,
            introduced: iOS(27), isDeprecated: false
          ),
        ]
      ),
      source: sdk
    )
    try await store.commitStagedIndex(signatures: [sdk.id: "sig"])

    let index = try #require(
      try await store.frameworkIndex(
        forModule: "PencilKit", source: sdk.id
      )
    )
    #expect(
      index.symbols.map(\.usr).sorted() == ["s:OnlyA", "s:OnlyB", "s:Shared"]
    )
    #expect(index.symbols.first { $0.usr == "s:Shared" }?.title == "First")
  }

  // MARK: - Multiple sources

  @Test(
    "Multiple sources coexist and reads filter to one",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func sourcesCoexistAndReadsFilterToOne() async throws {
    let store = try await Self.populatedStore()
    let older = Source(
      id: "apple-sdk:17F113", kind: .appleSDK, displayName: "Xcode 26.6"
    )
    try await store.replaceIndex(
      signature: "17F113|iphoneos26.0", source: older,
      frameworks: [
        FrameworkIndex(
          moduleName: "PencilKit",
          symbols: [
            IndexedSymbol(
              usr: "s:PKStroke", title: "PKStroke", kind: .structure,
              pathComponents: ["PKStroke"], parentUSR: nil,
              introduced: iOS(14), isDeprecated: false
            ),
          ]
        ),
      ]
    )

    #expect(
      try await store.frameworkIndex(
        forModule: "PencilKit", source: sdk.id
      )?.symbols.count == 4
    )
    #expect(
      try await store.frameworkIndex(forModule: "PencilKit", source: older.id)?
        .symbols.count == 1
    )
    #expect(
      try await store.signature(forSource: sdk.id)
        == "27A5194q|iphoneos27.0,macosx27.0"
    )
    #expect(
      try await store.signature(forSource: older.id) == "17F113|iphoneos26.0"
    )
    #expect(try await store.search(query: "grain", source: older.id).isEmpty)
    #expect(
      try await store.search(query: "grain", source: sdk.id).contains {
        $0.usr == "s:grainOffset"
      }
    )
  }

  @Test(
    "Removing a source leaves others intact",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func removingASourceLeavesOthersIntact() async throws {
    let store = try await Self.populatedStore()
    let older = Source(
      id: "apple-sdk:17F113", kind: .appleSDK, displayName: "Xcode 26.6"
    )
    try await store.replaceIndex(
      signature: "old", source: older, frameworks: [Self.swiftUI()]
    )

    try await store.removeSource(older.id)
    #expect(try await store.signature(forSource: older.id) == nil)
    #expect(try await store.search(query: "glass", source: older.id).isEmpty)
    #expect(
      try await store.frameworkIndex(forModule: "SwiftUI", source: sdk.id)
        != nil
    )
    #expect(try await store.sources() == [sdk])
  }

  // MARK: - Picker data

  @Test(
    "The store lists indexed platforms and releases",
    .tags(.versioning),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func listsIndexedPlatformsAndReleases() async throws {
    let store = try await Self.populatedStore()
    #expect(
      try await store.indexedPlatforms(source: sdk.id) == [.iOS, .macOS]
    )

    let iosReleases = try await store.indexedReleases(
      for: .iOS, source: sdk.id
    )
    #expect(iosReleases.first == SemanticVersion(major: 27))
    #expect(iosReleases.contains(SemanticVersion(major: 26)))
    #expect(iosReleases.contains(SemanticVersion(major: 14)))
    #expect(iosReleases == iosReleases.sorted(by: >))
  }

  @Test(
    "One query lists all releases grouped by platform",
    .tags(.versioning),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func listsAllReleasesByPlatformInOneQuery() async throws {
    let store = try await Self.populatedStore()
    let byPlatform = try await store.indexedReleasesByPlatform(
      source: sdk.id
    )
    #expect(byPlatform[.iOS]?.first == SemanticVersion(major: 27))
    #expect(byPlatform[.iOS]?.contains(SemanticVersion(major: 14)) == true)
    #expect(byPlatform[.macOS]?.contains(SemanticVersion(major: 27)) == true)
    #expect(byPlatform[.iOS] == byPlatform[.iOS]?.sorted(by: >))
  }

  // MARK: - Search

  @Test(
    "Search finds symbols by split identifier words",
    .tags(.search),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func findsSymbolsBySplitIdentifierWords() async throws {
    let store = try await Self.populatedStore()
    #expect(
      try await store.search(query: "Stroke", source: sdk.id).contains {
        $0.usr == "s:PKStroke"
      }
    )
    #expect(
      try await store.search(query: "grain", source: sdk.id).contains {
        $0.usr == "s:grainOffset"
      }
    )
  }

  @Test(
    "Search restricts results to a version selection",
    .tags(.search),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func restrictsSearchToSelection() async throws {
    let store = try await Self.populatedStore()
    let new27 = [
      VersionSelection(platform: .iOS, version: SemanticVersion(major: 27)),
    ]
    #expect(
      try await store.search(
        query: "Render", source: sdk.id, selections: new27
      ).contains {
        $0.usr == "s:RenderState"
      }
    )
    #expect(
      try await store.search(
        query: "Stroke", source: sdk.id, selections: new27
      ).isEmpty
    )
  }

  @Test(
    "An uppercase FTS5 keyword searches as text",
    .tags(.search),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func uppercaseFTS5KeywordSearchesAsText() async throws {
    let store = IndexStore()
    let kernel = FrameworkIndex(
      moduleName: "Kernel",
      symbols: [
        IndexedSymbol(
          usr: "c:NOTE_DELETE", title: "NOTE_DELETE", kind: .variable,
          pathComponents: ["NOTE_DELETE"], parentUSR: nil,
          introduced: iOS(26), isDeprecated: false
        ),
      ]
    )
    try await store.replaceFramework(kernel, source: sdk)
    #expect(
      try await store.search(query: "NOT", source: sdk.id).contains {
        $0.usr == "c:NOTE_DELETE"
      }
    )
  }

  @Test(
    "A result limit applies after the kind filter",
    .tags(.search),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func limitAppliesAfterKindFilter() async throws {
    let store = try await Self.populatedStore()
    let hits = try await store.search(
      query: "PK", source: sdk.id, kinds: [.property], limit: 1
    )
    #expect(hits.count == 1)
    #expect(hits.first?.kind == .property)
  }

  // MARK: - Pure helpers

  @Test(
    "Identifier words split at boundaries",
    .tags(.search),
    arguments: [
      ("PKStroke", "PK Stroke"),
      ("renderState", "render State"),
      ("utf8Data", "utf 8 Data"),
    ]
  )
  func splitsIdentifierWordsAtBoundaries(identifier: String, expected: String) {
    #expect(IndexStore.splitIdentifierWords(identifier) == expected)
  }

  @Test(
    "A prefix match expression builds from the query",
    .tags(.search),
    arguments: [(String, String?)](
      [
        ("render state", "\"render\"* \"state\"*"),
        ("  ", nil),
        ("PKStroke()", "\"PKStroke\"*"),
        ("NOT", "\"NOT\"*"),
        ("KERN_NOT_FOUND", "\"KERN\"* \"NOT\"* \"FOUND\"*"),
      ]
    )
  )
  func buildsPrefixMatchExpression(query: String, expected: String?) {
    #expect(IndexStore.ftsMatchExpression(for: query) == expected)
  }

  // MARK: - Helpers

  static func swiftUI() -> FrameworkIndex {
    FrameworkIndex(
      moduleName: "SwiftUI",
      symbols: [
        IndexedSymbol(
          usr: "s:View", title: "View", kind: .protocol,
          pathComponents: ["View"], parentUSR: nil,
          introduced: iOS(13), isDeprecated: false
        ),
        IndexedSymbol(
          usr: "s:glassEffect", title: "View.glassEffect", kind: .method,
          pathComponents: ["View", "glassEffect"], parentUSR: "s:View",
          introduced: iOS(26), isDeprecated: false
        ),
      ]
    )
  }

  static func populatedStore() async throws -> IndexStore {
    let store = IndexStore()
    try await store.replaceIndex(
      signature: "27A5194q|iphoneos27.0,macosx27.0",
      source: sdk,
      frameworks: [pencilKit(), swiftUI()]
    )
    return store
  }
}
