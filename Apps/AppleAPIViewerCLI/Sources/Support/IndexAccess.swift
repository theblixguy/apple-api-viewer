import ArgumentParser
import CoreModel
import Foundation
import IndexOrchestration
import IndexStore

struct IndexHandles {
  let store: IndexStore
  let workspace: IndexWorkspace
  let storageMode: IndexStore.StorageMode
  let databaseURL: URL
}

struct BuiltQuery {
  let query: SymbolQuery
  let source: Source.ID

  // The store's module lookup is byte-case-sensitive, and it returns an
  // empty result, not an error, for a name it does not have.
  func requireModule(
    _ module: String, format: OutputFormat
  ) async throws -> String {
    let names = try await query.frameworkNames(source: source)
    if names.contains(module) { return module }
    if let match = names.first(where: {
      $0.compare(module, options: .caseInsensitive) == .orderedSame
    }) {
      return match
    }
    throw fail(
      "No framework named '\(module)' in the index. Run 'apple-api-viewer-cli frameworks' to list the indexed frameworks.",
      code: ExitStatus.notFound, name: "notFound", format: format
    )
  }
}

extension GlobalOptions {
  func indexURL() throws -> URL {
    try databasePath.map { URL(filePath: $0) } ?? AppPaths.databaseURL()
  }

  // A build number resolves the index directly. An index whose Xcode is
  // gone stays queryable. Without a build number, the query uses the
  // active Xcode.
  func openBuiltQuery(xcodeBuild: String?) async throws -> BuiltQuery {
    _ = IndexStore.bootstrap(at: try indexURL())
    let store = IndexStore()
    let source: Source.ID
    let label: String
    if let xcodeBuild {
      source = Source.appleSDKID(forBuild: xcodeBuild)
      label = "Xcode build \(xcodeBuild)"
    } else {
      guard let xcode = await selectedXcode(build: nil) else {
        throw fail(
          "No Xcode found in /Applications. Install Xcode, or add one with 'apple-api-viewer-cli xcode add <path>'.",
          code: ExitStatus.noXcode, name: "noXcode", format: format
        )
      }
      source = Source.appleSDK(for: xcode).id
      label = xcode.displayName
    }
    guard try await store.signature(forSource: source) != nil else {
      throw fail(
        "No index for \(label). Run 'apple-api-viewer-cli index build' to build it, or 'apple-api-viewer-cli index status' to list the stored indexes.",
        code: ExitStatus.noIndex, name: "noIndex", format: format
      )
    }
    return BuiltQuery(query: SymbolQuery(store: store), source: source)
  }

  func openIndex() throws -> IndexHandles {
    let url = try indexURL()
    let mode = IndexStore.bootstrap(at: url)
    let store = IndexStore()
    return IndexHandles(
      store: store, workspace: IndexWorkspace(store: store, databaseURL: url),
      storageMode: mode, databaseURL: url
    )
  }
}

extension IndexHandles {
  // The in-memory fallback does not persist. Without this guard, a build
  // into it would run for minutes and vanish at process exit.
  func requirePersistentStorage(format: OutputFormat) throws {
    guard storageMode == .persistent else {
      throw fail(
        "Couldn't open the index database at \(databaseURL.path(percentEncoded: false)), so a build would not be saved. If the file is damaged, run 'apple-api-viewer-cli index delete' and build again.",
        code: ExitStatus.storageUnavailable, name: "storageUnavailable",
        format: format
      )
    }
  }
}

func withInterruptCancellation(
  _ body: @Sendable @escaping () async throws -> Void
) async throws {
  let task = Task { try await body() }
  // The code calls SIG_IGN first. Otherwise, the default SIGINT handler can
  // kill the process before the dispatch source delivers the signal.
  signal(SIGINT, SIG_IGN)
  let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
  source.setEventHandler { task.cancel() }
  source.resume()
  defer {
    source.cancel()
    signal(SIGINT, SIG_DFL)
  }
  try await task.value
}
