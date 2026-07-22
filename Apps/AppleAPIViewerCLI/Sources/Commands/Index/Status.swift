import ArgumentParser
import CoreModel
import Dependencies
import Foundation
import IndexOrchestration
import IndexStore

struct Status: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Show whether the index is current and where it lives."
  )

  // MARK: - Options

  @OptionGroup var options: GlobalOptions

  // MARK: - Run

  func run() async throws {
    @Dependency(\.xcodeRegistry) var registry
    let handles = try options.openIndex()
    let xcode = await registry.activeXcode()
    let upToDate: Bool = if let xcode {
      (try? await handles.workspace.isIndexUpToDate(for: xcode)) ?? false
    } else {
      false
    }
    let source = xcode.map { Source.appleSDK(for: $0).id }
    var built = false
    var platforms: [ApplePlatform] = []
    if let source {
      built = try await handles.store.signature(forSource: source) != nil
      if built {
        platforms = try await handles.store.indexedPlatforms(source: source)
      }
    }
    let indexes = try await handles.workspace.indexedSources()
    let output = StatusOutput(
      built: built,
      upToDate: upToDate,
      xcode: xcode.map(XcodeSummary.init),
      storage: handles.storageMode == .persistent
        ? "persistent" : "inMemoryFallback",
      databasePath: handles.databaseURL.path(percentEncoded: false),
      platforms: platforms.map(\.rawValue),
      indexes: indexes.map(\.source.displayName)
    )
    emitOne(output, as: options.format) { Self.statusText(output) }
  }

  // MARK: - Helpers

  private static func statusText(_ status: StatusOutput) -> String {
    var lines: [String] = []
    if !status.built {
      lines.append("No index. Run 'apple-api-viewer-cli index build' first.")
    } else {
      lines.append(status.upToDate ? "Index is up to date." : "Index is stale.")
    }
    if let xcode = status.xcode {
      lines.append(xcode.displayName)
    }
    if !status.platforms.isEmpty {
      lines.append("Platforms \(status.platforms.joined(separator: ", "))")
    }
    if !status.indexes.isEmpty {
      lines.append("Indexes \(status.indexes.joined(separator: ", "))")
    }
    lines.append("Storage \(status.storage)")
    lines.append(status.databasePath)
    return lines.joined(separator: "\n")
  }
}

// MARK: - Output types

struct StatusOutput: Encodable {
  let built: Bool
  let upToDate: Bool
  let xcode: XcodeSummary?
  let storage: String
  let databasePath: String
  let platforms: [String]
  let indexes: [String]
}
