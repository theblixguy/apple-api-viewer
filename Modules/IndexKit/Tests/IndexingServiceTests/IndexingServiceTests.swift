import CoreModel
import Dependencies
import DependenciesTestSupport
import Foundation
import IndexStore
import SymbolGraphIndex
import SymbolSource
import Testing
@testable import IndexingService

@Suite("Indexing service orchestration", .tags(.indexing))
struct IndexingServiceOrchestrationTests {
  @Test("The signature combines the format version and source signature")
  func signatureCombinesFormatVersionAndSourceSignature() {
    let source = MockSource(
      source: testSDK, stubSignature: "abc", frameworks: []
    )
    let service = IndexingService(sources: [source], store: IndexStore())
    #expect(service.signature(of: source) == "v3|abc")
  }

  @Test(
    "Building the index persists frameworks, the signature, and the source",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func buildIndexPersistsSourceFrameworksSignatureAndSource() async throws {
    let store = IndexStore()
    let service = Self.service(
      signature: "sig1",
      frameworks: [Self.framework("PencilKit", usr: "s:PK", title: "PKThing")],
      store: store
    )
    try await service.buildIndex()

    #expect(try await store.allFrameworkNames() == ["PencilKit"])
    #expect(try await store.signature(forSource: testSDK.id) == "v3|sig1")
    #expect(try await store.sources() == [testSDK])
    #expect(try await service.isIndexUpToDate())
  }

  @Test(
    "Indexing a module replaces one framework and leaves others",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func indexModuleReplacesOneFrameworkLeavingOthers() async throws {
    let store = IndexStore()
    try await store.replaceIndex(
      signature: "old",
      source: testSDK,
      frameworks: [
        Self.framework("PencilKit", usr: "s:Old", title: "OldThing"),
        Self.framework("SwiftUI", usr: "s:View", title: "View"),
      ]
    )

    let service = Self.service(
      signature: "x",
      frameworks: [
        Self.framework("PencilKit", usr: "s:New", title: "NewThing"),
      ],
      store: store
    )
    #expect(try await service.indexModule("PencilKit"))

    #expect(
      try await store.frameworkIndex(
        forModule: "PencilKit", source: testSDK.id
      )?.symbols.map(
        \.title
      ) == ["NewThing"]
    )
    #expect(
      try await store.frameworkIndex(forModule: "SwiftUI", source: testSDK.id)?
        .symbols.contains {
          $0.title == "View"
        }
        == true
    )
  }

  @Test(
    "Indexing a module returns false when no source provides it",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func indexModuleReturnsFalseWhenNoSourceProvidesTheModule() async throws {
    let store = IndexStore()
    try await store.replaceIndex(
      signature: "old", source: testSDK,
      frameworks: [Self.framework("SwiftUI", usr: "s:View", title: "View")]
    )

    let service = Self.service(signature: "x", frameworks: [], store: store)
    #expect(try await service.indexModule("PencilKit") == false)
    #expect(
      try await store.frameworkIndex(forModule: "SwiftUI", source: testSDK.id)
        != nil
    )
  }

  @Test(
    "Indexing a module rethrows extraction failures instead of swallowing them",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func indexModuleRethrowsExtractionFailuresInsteadOfSwallowingThem()
    async throws
  {
    let store = IndexStore()
    let service = IndexingService(
      sources: [
        MockSource(
          source: testSDK, stubSignature: "x",
          frameworks: [
            Self.framework("PencilKit", usr: "s:PK", title: "PKThing"),
          ],
          makeFrameworkFails: true
        ),
      ],
      store: store
    )

    await #expect(throws: MockSource.ExtractionFailed.self) {
      try await service.indexModule("PencilKit")
    }
  }

  @Test(
    "Index freshness reflects a source signature change",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func isIndexUpToDateReflectsSourceSignatureChange() async throws {
    let store = IndexStore()
    try await Self.service(signature: "sigA", frameworks: [], store: store)
      .buildIndex()
    #expect(
      try await Self.service(signature: "sigA", frameworks: [], store: store)
        .isIndexUpToDate()
    )
    #expect(
      try await Self.service(signature: "sigB", frameworks: [], store: store)
        .isIndexUpToDate()
        == false
    )
  }

  @Test(
    "Building the index reports per-module progress then saving",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func buildIndexReportsPerModuleProgressThenSaving() async throws {
    let store = IndexStore()
    let service = Self.service(
      signature: "sig1",
      frameworks: [
        Self.framework("PencilKit", usr: "s:PK", title: "PKThing"),
        Self.framework("SwiftUI", usr: "s:SUI", title: "SUIThing"),
      ],
      store: store
    )

    let collector = ProgressCollector()
    try await service.buildIndex { progress in
      await collector.append(progress)
    }

    let values = await collector.values
    #expect(values.map(\.completed) == [1, 2, 0])
    #expect(values.map(\.currentModule) == ["PencilKit", "SwiftUI", nil])
    #expect(values.dropLast().allSatisfy { $0.phase == .extracting })
    #expect(values.last?.phase == .saving)
  }

  @Test(
    "Canceling a build leaves the staged build uncommitted",
    .dependency(\.defaultDatabase, try IndexStore.makeInMemoryDatabase())
  )
  func cancelingBuildIndexLeavesTheStagedBuildUncommitted() async throws {
    let store = IndexStore()
    let latch = ExtractionLatch()
    let service = IndexingService(
      sources: [BlockingSource(source: testSDK, latch: latch)], store: store
    )

    let signatureBefore = try await store.signature(forSource: testSDK.id)

    let task = Task { try await service.buildIndex() }
    await latch.wait()
    task.cancel()

    await #expect(throws: CancellationError.self) {
      try await task.value
    }
    #expect(try await store.signature(forSource: testSDK.id) == signatureBefore)
  }

  // MARK: - Helpers

  static func framework(_ name: String, usr: String, title: String)
    -> FrameworkIndex
  {
    FrameworkIndex(
      moduleName: name,
      symbols: [
        IndexedSymbol(
          usr: usr, title: title, kind: .structure,
          pathComponents: [title], parentUSR: nil,
          introduced: [.iOS: SemanticVersion(major: 27)], isDeprecated: false
        ),
      ]
    )
  }

  static func service(
    signature: String, frameworks: [FrameworkIndex], store: IndexStore
  )
    -> IndexingService
  {
    IndexingService(
      sources: [
        MockSource(
          source: testSDK, stubSignature: signature, frameworks: frameworks
        ),
      ],
      store: store
    )
  }
}

// MARK: - Test support

private let testSDK = Source(
  id: "apple-sdk:test", kind: .appleSDK, displayName: "Test SDK"
)

private struct MockSource: SymbolSource {
  struct ExtractionFailed: Error {}

  let source: Source
  let stubSignature: String
  let frameworks: [FrameworkIndex]
  var makeFrameworkFails = false

  func signature() -> String { stubSignature }

  func extractFrameworks(
    progress: @escaping @Sendable (IndexingProgress) async -> Void,
    consume: @escaping @Sendable (FrameworkIndex) async throws -> Void
  ) async throws {
    for (index, framework) in frameworks.enumerated() {
      try await consume(framework)
      await progress(
        IndexingProgress(
          completed: index + 1, total: frameworks.count,
          currentModule: framework.moduleName
        )
      )
    }
  }

  func makeFramework(named moduleName: String) async throws -> FrameworkIndex? {
    if makeFrameworkFails { throw ExtractionFailed() }
    return frameworks.first { $0.moduleName == moduleName }
  }
}

private actor ProgressCollector {
  private(set) var values: [IndexingProgress] = []

  func append(_ value: IndexingProgress) {
    values.append(value)
  }
}

// A test suspends on this latch until extraction reaches its blocking
// point. A cancellation then lands mid-extraction instead of racing a
// poll loop against task scheduling.
private actor ExtractionLatch {
  private var isReady = false
  private var readyContinuation: CheckedContinuation<Void, Never>?

  func wait() async {
    if isReady { return }
    await withCheckedContinuation { readyContinuation = $0 }
  }

  func signal() {
    isReady = true
    readyContinuation?.resume()
    readyContinuation = nil
  }
}

// A source whose extraction blocks until the calling task is canceled, so a
// test can cancel `buildIndex()` mid-extraction and observe the result.
private struct BlockingSource: SymbolSource {
  let source: Source
  let latch: ExtractionLatch

  func signature() -> String { "blocking" }

  func extractFrameworks(
    progress: @escaping @Sendable (IndexingProgress) async -> Void,
    consume: @escaping @Sendable (FrameworkIndex) async throws -> Void
  ) async throws {
    await latch.signal()
    try await Task.sleep(for: .seconds(60))
  }

  func makeFramework(named moduleName: String) async throws -> FrameworkIndex? {
    nil
  }
}
