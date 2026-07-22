import AppleSDKSource
import CoreModel
import Foundation
import IndexStore
import SymbolGraphIndex
import SymbolSource

package struct IndexingService: Sendable {
  private let sources: [any SymbolSource]
  private let store: IndexStore

  package init(sources: [any SymbolSource], store: IndexStore) {
    self.sources = sources
    self.store = store
  }

  package init(xcode: XcodeInstallation, store: IndexStore) {
    self.init(sources: [SDKSymbolSource(xcode: xcode)], store: store)
  }

  static let indexFormatVersion = 3

  package func signature(of source: some SymbolSource) -> String {
    "v\(Self.indexFormatVersion)|\(source.signature())"
  }

  package func isIndexUpToDate() async throws -> Bool {
    for source in sources {
      guard try await store.signature(forSource: source.source.id)
        == signature(of: source)
      else { return false }
    }
    return true
  }

  package func buildIndex(
    progress: @Sendable @escaping (IndexingProgress) async -> Void = { _ in }
  ) async throws {
    try await store.beginStagedIndex()
    var signatures: [Source.ID: String] = [:]
    for source in sources {
      let identity = source.source
      let signatureBeforeExtraction = signature(of: source)
      try await store.stageSource(identity)
      try await source.extractFrameworks(progress: progress) { framework in
        try await store.stageFramework(framework, source: identity)
      }
      try Task.checkCancellation()
      // An SDK download can finish, or the Xcode can be deleted, during a
      // long build. Without this check, a partial index would commit with
      // a signature that still matches, and `isIndexUpToDate` would report
      // it complete forever.
      guard signature(of: source) == signatureBeforeExtraction else {
        throw ToolchainChangedError()
      }
      signatures[identity.id] = signatureBeforeExtraction
    }
    await progress(
      IndexingProgress(
        completed: 0, total: 0, currentModule: nil, phase: .saving
      )
    )
    try await store.commitStagedIndex(signatures: signatures)
  }

  package func indexModule(_ moduleName: String) async throws -> Bool {
    for source in sources {
      if let framework = try await source.makeFramework(named: moduleName) {
        try await store.replaceFramework(framework, source: source.source)
        return true
      }
    }
    return false
  }
}
