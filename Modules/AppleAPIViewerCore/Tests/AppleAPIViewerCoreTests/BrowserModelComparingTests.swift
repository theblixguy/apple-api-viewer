import CoreModel
import Dependencies
import DependenciesTestSupport
import IndexStore
import SymbolGraphIndex
import Testing
@testable import AppleAPIViewerCore

@MainActor
@Suite("Browser model comparing", .tags(.browsing, .diffing))
struct BrowserModelComparingTests {
  private static let sdk = Source(
    id: "apple-sdk:27A5194q", kind: .appleSDK, displayName: "Xcode 27.0"
  )
  private static let older = Source(
    id: "apple-sdk:17F113", kind: .appleSDK, displayName: "Xcode 26.6"
  )

  @Test(
    "Comparing sets the baseline and stopping clears every selection",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func comparingSetsBaselineAndStoppingClearsSelections() async throws {
    let model = try await makeModel()

    model.compare(against: Self.older)
    #expect(model.isComparing)
    #expect(model.comparisonSource == Self.older.id)
    #expect(model.comparisonDisplayName == "Xcode 26.6")

    model.selectedDiffModule = "PencilKit"
    let diff = try #require(await model.diff(forModule: "PencilKit"))
    model.selectedDiffEntry = DiffEntry(
      category: .added, symbol: try #require(diff.added.first)
    )

    model.stopComparing()
    #expect(!model.isComparing)
    #expect(model.comparisonDisplayName == nil)
    #expect(model.selectedDiffModule == nil)
    #expect(model.selectedDiffEntry == nil)
  }

  @Test(
    "Comparing against the active source does nothing",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func comparingAgainstActiveSourceDoesNothing() async throws {
    let model = try await makeModel()
    model.compare(against: Self.sdk)
    #expect(!model.isComparing)
  }

  @Test(
    "Switching frameworks clears the selected diff entry",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func switchingFrameworksClearsSelectedDiffEntry() async throws {
    let model = try await makeModel()
    model.compare(against: Self.older)
    model.selectedDiffModule = "PencilKit"
    let diff = try #require(await model.diff(forModule: "PencilKit"))
    model.selectedDiffEntry = DiffEntry(
      category: .added, symbol: try #require(diff.added.first)
    )

    model.selectedDiffModule = "SwiftUI"

    #expect(model.selectedDiffEntry == nil)
  }

  @Test(
    "Diff summaries list the differences between the compared indexes",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func diffSummariesListDifferences() async throws {
    let model = try await makeModel()
    model.compare(against: Self.older)

    let summaries = try #require(await model.diffSummaries())

    #expect(summaries.map(\.moduleName) == ["PencilKit"])
    #expect(summaries.first?.addedCount == 1)
    #expect(summaries.first?.removedCount == 1)
  }

  @Test(
    "The framework diff resolves symbols from both indexes",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func frameworkDiffResolvesBothIndexes() async throws {
    let model = try await makeModel()
    model.compare(against: Self.older)

    let diff = try #require(await model.diff(forModule: "PencilKit"))

    #expect(diff.added.map(\.usr) == ["s:RenderState"])
    #expect(diff.removed.map(\.usr) == ["s:OldOnly"])
  }

  @Test(
    "Switching the active source to the baseline stops comparing",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func switchingActiveSourceToBaselineStopsComparing() async throws {
    let model = try await makeModel()
    model.compare(against: Self.older)

    model.activeSource = Self.older.id

    #expect(!model.isComparing)
  }

  @Test(
    "Comparison candidates exclude the active source",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func comparisonCandidatesExcludeActiveSource() async throws {
    let model = try await makeModel()

    let candidates = await model.comparisonCandidates()

    #expect(candidates.map(\.id) == [Self.older.id])
  }

  // MARK: - Helpers

  private func makeModel() async throws -> BrowserModel {
    let store = IndexStore()
    try await store.replaceIndex(
      bySource: [
        Self.sdk: [
          FrameworkIndex(
            moduleName: "PencilKit",
            symbols: [
              Self.symbol(usr: "s:PKStroke", path: ["PKStroke"]),
              Self.symbol(
                usr: "s:RenderState", path: ["PKStroke", "RenderState"]
              ),
            ]
          ),
        ],
        Self.older: [
          FrameworkIndex(
            moduleName: "PencilKit",
            symbols: [
              Self.symbol(usr: "s:PKStroke", path: ["PKStroke"]),
              Self.symbol(usr: "s:OldOnly", path: ["OldOnly"]),
            ]
          ),
        ],
      ],
      signatures: [
        Self.sdk.id: "27A5194q|iphoneos27.0",
        Self.older.id: "17F113|iphoneos26.6",
      ]
    )
    let model = BrowserModel(store: store)
    model.activeSource = Self.sdk.id
    return model
  }

  private static func symbol(usr: String, path: [String]) -> IndexedSymbol {
    IndexedSymbol(
      usr: usr,
      title: path.joined(separator: "."),
      kind: .structure,
      pathComponents: path,
      parentUSR: nil,
      introduced: [.iOS: SemanticVersion(major: 26)],
      isDeprecated: false
    )
  }
}
