import ArgumentParser
import CoreModel
import IndexOrchestration

struct Platforms: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "List indexed platforms and their OS releases."
  )

  @OptionGroup var options: GlobalOptions
  @OptionGroup var indexSelection: IndexSelectionOptions

  func run() async throws {
    let built = try await options.openBuiltQuery(
      xcodeBuild: indexSelection.xcodeBuild
    )
    let byPlatform = try await built.query.indexedReleasesByPlatform(
      source: built.source
    )
    let output = ApplePlatform.allCases.compactMap {
      platform -> PlatformOutput? in
      let releases = (byPlatform[platform] ?? []).filter { !$0.isUnversioned }
      guard !releases.isEmpty else { return nil }
      return PlatformOutput(
        platform: platform.rawValue, releases: releases.map(\.description)
      )
    }
    emit(output, as: options.format) {
      "\($0.platform)  \($0.releases.joined(separator: ", "))"
    }
  }
}

struct PlatformOutput: Encodable {
  let platform: String
  let releases: [String]
}
