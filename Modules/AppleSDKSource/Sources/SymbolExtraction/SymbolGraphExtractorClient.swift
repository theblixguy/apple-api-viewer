import CoreModel
import Dependencies
import Foundation

package struct SymbolGraphExtractorClient: Sendable {
  private let _extractableModules: @Sendable (InstalledSDK) -> [String]
  private let _extract:
    @Sendable (
      XcodeInstallation, String, InstalledSDK, URL, SymbolGraphAccessLevel
    )
    async throws -> [URL]
  private let _verifyToolchain: @Sendable (XcodeInstallation) throws -> Void

  package init(
    extractableModules: @escaping @Sendable (InstalledSDK) -> [String],
    extract:
    @escaping @Sendable (
      XcodeInstallation, String, InstalledSDK, URL, SymbolGraphAccessLevel
    ) async throws -> [URL],
    verifyToolchain: @escaping @Sendable (XcodeInstallation) throws -> Void
  ) {
    _extractableModules = extractableModules
    _extract = extract
    _verifyToolchain = verifyToolchain
  }

  package func extractableModules(in sdk: InstalledSDK) -> [String] {
    _extractableModules(sdk)
  }

  package func extract(
    xcode: XcodeInstallation,
    module: String,
    sdk: InstalledSDK,
    into outputDirectory: URL,
    minimumAccessLevel: SymbolGraphAccessLevel = .public
  ) async throws -> [URL] {
    try await _extract(xcode, module, sdk, outputDirectory, minimumAccessLevel)
  }

  package func verifyToolchain(xcode: XcodeInstallation) throws {
    try _verifyToolchain(xcode)
  }
}

extension SymbolGraphExtractorClient: DependencyKey {
  package static let liveValue = SymbolGraphExtractorClient(
    extractableModules: { sdk in
      SymbolGraphExtractor.extractableModules(in: sdk)
    },
    extract: { xcode, module, sdk, directory, level in
      try await SymbolGraphExtractor.extract(
        xcode: xcode, module: module, sdk: sdk, into: directory,
        minimumAccessLevel: level
      )
    },
    verifyToolchain: { xcode in
      try SymbolGraphExtractor.verifyToolchain(xcode: xcode)
    }
  )

  // The test value defaults to the live run, so an integration test
  // extracts for real unless it overrides the client.
  package static let testValue = liveValue
}

extension DependencyValues {
  package var symbolGraphExtractor: SymbolGraphExtractorClient {
    get { self[SymbolGraphExtractorClient.self] }
    set { self[SymbolGraphExtractorClient.self] = newValue }
  }
}
