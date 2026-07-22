import CoreModel
import Dependencies
import DependenciesTestSupport
import Foundation
import IndexStore
import Observation
import SQLiteData
import SymbolGraphIndex
import Testing
@testable import AppleAPIViewerCore

@MainActor
@Suite("Browser model", .tags(.browsing))
struct BrowserModelTests {
  private static let sdk = Source(
    id: "apple-sdk:27A5194q", kind: .appleSDK, displayName: "Xcode 27.0"
  )

  @Test(
    "Switching frameworks clears the selected symbol",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func switchingFrameworksClearsTheSelectedSymbol() async throws {
    let model = try await makeModel()
    model.selectedFramework = FrameworkPick(
      platform: .iOS, moduleName: "PencilKit"
    )
    model.selectedSymbol = SymbolReference(
      usr: "s:PKStroke", moduleName: "PencilKit"
    )

    model.selectedFramework = FrameworkPick(
      platform: .iOS, moduleName: "SwiftUI"
    )

    #expect(model.selectedSymbol == nil)
  }

  @Test(
    "Loads picker data and defaults to newest release",
    .tags(.versioning),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func loadsPickerDataAndDefaultsToNewestRelease() async throws {
    let model = try await makeModel()
    await model.loadPickerData()
    #expect(model.indexedPlatforms.contains(.iOS))
    #expect(model.isSelected(.iOS, SemanticVersion(major: 27)))
    #expect(
      model.selections.contains(
        VersionSelection(platform: .iOS, version: SemanticVersion(major: 27))
      )
    )
  }

  @Test(
    "Selecting multiple versions updates selections and label",
    .tags(.versioning),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func selectingMultipleVersionsUpdatesSelectionsAndLabel() async throws {
    let model = try await makeModel()
    let v26 = SemanticVersion(major: 26)
    let v27 = SemanticVersion(major: 27)

    model.toggle(.iOS, v26)
    model.toggle(.iOS, v27)

    #expect(model.isSelected(.iOS, v26))
    #expect(model.isSelected(.iOS, v27))
    #expect(
      model.selections == [
        VersionSelection(platform: .iOS, version: v27),
        VersionSelection(platform: .iOS, version: v26),
      ]
    )
    #expect(model.selectionLabel(for: .iOS) == "27.0, 26.0")

    model.toggle(.iOS, v27)
    #expect(model.selectionLabel(for: .iOS) == "26.0")
    model.clearSelection(for: .iOS)
    #expect(model.selections.isEmpty)
    #expect(model.selectionLabel(for: .iOS) == "Off")

    #expect(
      BrowserModel.versionLabel(
        SemanticVersion(major: SemanticVersion.unversionedMajor)
      )
        == "Unversioned"
    )
  }

  @Test(
    "Lists frameworks for platform",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func listsFrameworksForPlatform() async throws {
    let model = try await makeModel()
    model.toggle(.iOS, SemanticVersion(major: 27))
    let frameworks = try #require(await model.frameworks(forPlatform: .iOS))
    #expect(
      frameworks.contains {
        $0.moduleName == "PencilKit" && $0.newSymbolCount == 1
      }
    )
  }

  @Test(
    "Unions selected versions across frameworks and tree",
    .tags(.symbolTree),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func unionsSelectedVersionsAcrossFrameworksAndTree() async throws {
    let model = try await makeModel()
    model.toggle(.iOS, SemanticVersion(major: 26))
    model.toggle(.iOS, SemanticVersion(major: 27))

    let frameworks = try #require(await model.frameworks(forPlatform: .iOS))
    #expect(
      frameworks.contains {
        $0.moduleName == "PencilKit" && $0.newSymbolCount == 2
      }
    )

    let nodes = try #require(
      await model.tree(
        for: FrameworkPick(platform: .iOS, moduleName: "PencilKit")
      )
    )
    let rootTitles = nodes.map(\.symbol.title)
    #expect(rootTitles.contains("PKCanvasView"))
    // PKStroke is an ancestor of the version-27 match.
    #expect(rootTitles.contains("PKStroke"))
  }

  @Test(
    "Builds tree nesting new member under type",
    .tags(.symbolTree),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func buildsTreeNestingNewMemberUnderType() async throws {
    let model = try await makeModel()
    model.toggle(.iOS, SemanticVersion(major: 27))
    let pick = FrameworkPick(platform: .iOS, moduleName: "PencilKit")
    let nodes = try #require(await model.tree(for: pick))
    #expect(nodes.first?.symbol.title == "PKStroke")
    #expect(nodes.first?.children.first?.symbol.title == "PKStroke.RenderState")
  }

  @Test(
    "Kind filter narrows tree",
    .tags(.symbolTree),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func kindFilterNarrowsTree() async throws {
    let model = try await makeModel()
    model.toggle(.iOS, SemanticVersion(major: 27))
    let pick = FrameworkPick(platform: .iOS, moduleName: "PencilKit")

    let unfiltered = try #require(await model.tree(for: pick))
    #expect(!unfiltered.isEmpty)

    model.toggleKind(.method)
    let methodsOnly = try #require(await model.tree(for: pick))
    #expect(methodsOnly.isEmpty)

    model.clearKinds()
    model.toggleKind(.structure)
    let structsOnly = try #require(await model.tree(for: pick))
    #expect(!structsOnly.isEmpty)
  }

  @Test(
    "Resolves symbol and builds documentation URL",
    .tags(.documentation),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func resolvesSymbolAndBuildsDocumentationURL() async throws {
    let model = try await makeModel()
    let symbol = try #require(
      await model.resolveSymbol(
        SymbolReference(usr: "s:RenderState", moduleName: "PencilKit")
      )
    )
    #expect(symbol.title == "PKStroke.RenderState")
    #expect(
      model.documentationURL(for: symbol, in: "PencilKit").absoluteString
        == "https://developer.apple.com/documentation/pencilkit/pkstroke/renderstate"
    )
  }

  @Test(
    "Switching active source changes results",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func switchingActiveSourceChangesResults() async throws {
    let model = try await makeModel()
    let older = Source(
      id: "apple-sdk:17F113", kind: .appleSDK, displayName: "Xcode 26.6"
    )
    try await model.store.replaceIndex(
      signature: "old", source: older,
      frameworks: [
        FrameworkIndex(
          moduleName: "PencilKit",
          symbols: [
            IndexedSymbol(
              usr: "s:OldOnly", title: "OldOnly", kind: .structure,
              pathComponents: ["OldOnly"], parentUSR: nil,
              introduced: [.iOS: SemanticVersion(major: 26)],
              isDeprecated: false
            ),
          ]
        ),
      ]
    )
    model.toggle(.iOS, SemanticVersion(major: 26))
    _ = try #require(
      await model.tree(
        for: FrameworkPick(platform: .iOS, moduleName: "PencilKit")
      )
    )

    let revision = model.dataRevision
    model.activeSource = older.id
    #expect(model.dataRevision == revision + 1)

    let tree = try #require(
      await model.tree(
        for: FrameworkPick(platform: .iOS, moduleName: "PencilKit")
      )
    )
    #expect(tree.map(\.symbol.usr) == ["s:OldOnly"])
  }

  @Test(
    "Switching sources prunes unavailable selections",
    .tags(.versioning),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func switchingSourcesPrunesUnavailableSelections() async throws {
    let model = try await makeModel()
    await model.loadPickerData()
    model.toggle(.iOS, SemanticVersion(major: 26))
    #expect(model.isSelected(.iOS, SemanticVersion(major: 27)))
    #expect(model.isSelected(.iOS, SemanticVersion(major: 26)))

    let older = Source(
      id: "apple-sdk:17F113", kind: .appleSDK, displayName: "Xcode 26.6"
    )
    try await model.store.replaceIndex(
      signature: "old", source: older,
      frameworks: [
        FrameworkIndex(
          moduleName: "PencilKit",
          symbols: [
            IndexedSymbol(
              usr: "s:OldOnly", title: "OldOnly", kind: .structure,
              pathComponents: ["OldOnly"], parentUSR: nil,
              introduced: [.iOS: SemanticVersion(major: 26)],
              isDeprecated: false
            ),
          ]
        ),
      ]
    )
    model.activeSource = older.id
    await model.loadPickerData()

    #expect(!model.isSelected(.iOS, SemanticVersion(major: 27)))
    #expect(model.isSelected(.iOS, SemanticVersion(major: 26)))
    #expect(model.selections.map(\.platform) == [.iOS])
  }

  @Test(
    "Search finds matches",
    .tags(.search),
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func searchFindsMatches() async throws {
    let model = try await makeModel()
    model.searchText = "Render"
    #expect(
      try #require(await model.searchResults()).contains {
        $0.usr == "s:RenderState"
      }
    )
  }

  @Test(
    "Search loop publishes debounced hits", .tags(.search),
    .timeLimit(.minutes(1))
  )
  func searchLoopPublishesDebouncedHits() async throws {
    try await withDependencies {
      $0.defaultDatabase = try IndexStore.makeInMemoryDatabase()
      // The wiring from text to published hits is under test, not the
      // debounce interval. An immediate clock collapses the wait.
      $0.continuousClock = ImmediateClock()
    } operation: {
      let model = try await makeModel()
      model.searchText = "Render"
      let task = Task { await model.runSearch() }
      defer { task.cancel() }

      // Subscribing before the first suspension means the search task
      // cannot publish until this iteration is already waiting.
      var published: [SearchHit] = []
      for await hits in Observations({ model.searchHits }) where !hits.isEmpty {
        published = hits
        break
      }
      #expect(published.contains { $0.usr == "s:RenderState" })
    }
  }

  @Test("Failing read sets load error")
  func failingReadSetsLoadError() async throws {
    let database = try IndexStore.makeInMemoryDatabase()
    try await withDependencies {
      $0.defaultDatabase = database
    } operation: {
      let model = try await makeModel()
      model.toggle(.iOS, SemanticVersion(major: 27))
      try database.close()

      let frameworks = await model.frameworks(forPlatform: .iOS)
      #expect(frameworks == nil)
      #expect(model.loadError != nil)
    }
  }

  @Test("Dismiss load error clears it")
  func dismissLoadErrorClearsIt() async throws {
    let database = try IndexStore.makeInMemoryDatabase()
    try await withDependencies {
      $0.defaultDatabase = database
    } operation: {
      let model = try await makeModel()
      model.toggle(.iOS, SemanticVersion(major: 27))
      try database.close()
      _ = await model.frameworks(forPlatform: .iOS)
      #expect(model.loadError != nil)

      model.dismissLoadError()
      #expect(model.loadError == nil)
    }
  }

  // MARK: - Helpers

  private func makeModel() async throws -> BrowserModel {
    let store = IndexStore()
    let pencilKit = FrameworkIndex(
      moduleName: "PencilKit",
      symbols: [
        IndexedSymbol(
          usr: "s:PKStroke", title: "PKStroke", kind: .structure,
          pathComponents: ["PKStroke"], parentUSR: nil,
          introduced: [.iOS: SemanticVersion(major: 14)], isDeprecated: false
        ),
        IndexedSymbol(
          usr: "s:RenderState", title: "PKStroke.RenderState", kind: .structure,
          pathComponents: ["PKStroke", "RenderState"], parentUSR: "s:PKStroke",
          introduced: [
            .iOS: SemanticVersion(major: 27),
            .macOS: SemanticVersion(major: 27),
          ],
          isDeprecated: false
        ),
        IndexedSymbol(
          usr: "s:PKCanvasView", title: "PKCanvasView", kind: .structure,
          pathComponents: ["PKCanvasView"], parentUSR: nil,
          introduced: [.iOS: SemanticVersion(major: 26)], isDeprecated: false
        ),
      ]
    )
    try await store.replaceIndex(
      signature: "27A5194q|iphoneos27.0", source: Self.sdk,
      frameworks: [pencilKit]
    )
    let model = BrowserModel(store: store)
    model.activeSource = Self.sdk.id
    return model
  }
}
