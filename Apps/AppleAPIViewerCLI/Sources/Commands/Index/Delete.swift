import ArgumentParser
import CoreModel
import Foundation
import IndexOrchestration
import IndexStore

struct Delete: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "delete",
    abstract: "Delete the index so the next build starts fresh."
  )

  // MARK: - Options

  @OptionGroup var options: GlobalOptions

  @Option(
    name: .customLong("xcode"),
    help: """
    Delete only this Xcode's index, by build number, including one whose
    Xcode is gone.
    """
  )
  var xcodeBuild: String?

  // MARK: - Run

  func run() async throws {
    if let xcodeBuild {
      try await deleteIndex(forBuild: xcodeBuild)
      return
    }
    let handles = try options.openIndex()
    let base = handles.databaseURL.path(percentEncoded: false)
    let deleted: Bool
    if handles.storageMode == .persistent {
      // The app can hold the database file open in another process. An
      // unlink would split the two processes onto different files until
      // the app relaunches, so the delete goes through SQL instead.
      deleted = try await handles.workspace.deleteAllIndexes()
    } else {
      let fileManager = FileManager.default
      var removedAny = false
      for path in [base, base + "-shm", base + "-wal"]
        where
        fileManager.fileExists(atPath: path)
      {
        try fileManager.removeItem(atPath: path)
        removedAny = true
      }
      deleted = removedAny
    }
    let output = DeleteOutput(deleted: deleted, databasePath: base)
    emitOne(output, as: options.format) {
      deleted ? "Deleted the index at \(base)." : "No index to delete."
    }
  }

  // MARK: - Helpers

  // The index of an uninstalled Xcode must stay deletable, so the build
  // number resolves against the stored indexes, not the installed Xcodes.
  private func deleteIndex(forBuild build: String) async throws {
    let handles = try options.openIndex()
    let sourceID = Source.appleSDKID(forBuild: build)
    let sources = try await handles.workspace.indexedSources()
    guard let indexed = sources.first(where: { $0.id == sourceID }) else {
      throw fail(
        "No index for Xcode build \(build). Run 'apple-api-viewer-cli index status' to list the stored indexes.",
        code: ExitStatus.notFound, name: "notFound", format: options.format
      )
    }
    try await handles.workspace.deleteIndex(forSource: indexed.id)
    let output = DeleteOutput(
      deleted: true,
      databasePath: handles.databaseURL.path(percentEncoded: false)
    )
    emitOne(output, as: options.format) {
      "Deleted the index for \(indexed.source.displayName)."
    }
  }
}

// MARK: - Output types

struct DeleteOutput: Encodable {
  let deleted: Bool
  let databasePath: String
}
