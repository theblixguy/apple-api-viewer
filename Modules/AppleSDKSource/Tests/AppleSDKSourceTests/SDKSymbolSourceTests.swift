import CoreModel
import Foundation
import SDKDiscovery
import SymbolGraphIndex
import Testing
@testable import AppleSDKSource

@Suite(
  "SDK symbol source integration",
  .tags(.extraction),
  .enabled(if: SDKDiscovery.latestXcode() != nil)
)
struct SDKSymbolSourceIntegrationTests {
  @Test("Units are built for requested platforms")
  func buildsUnitsForRequestedPlatforms() throws {
    let xcode = try #require(SDKDiscovery.latestXcode())
    let source = SDKSymbolSource(xcode: xcode)

    let units = source.makeUnits(platforms: [.iOS])
    #expect(!units.isEmpty)
    #expect(units.allSatisfy { $0.sdk.platform == .iOS })
    #expect(units.contains { $0.module == "PencilKit" })
    #expect(units.allSatisfy { !$0.module.hasPrefix("_") })
  }

  @Test("Installed platforms, signature, and identity are reported")
  func reportsInstalledPlatformsSignatureAndIdentity() throws {
    let xcode = try #require(SDKDiscovery.latestXcode())
    let source = SDKSymbolSource(xcode: xcode)

    let platforms = source.installedPlatforms()
    #expect(platforms.contains(.iOS))
    #expect(platforms.contains(.macOS))

    let signature = source.signature()
    #expect(signature.contains(xcode.build))
    #expect(signature.contains("iphoneos"))

    #expect(source.source == Source.appleSDK(for: xcode))
  }
}

@Suite(
  "SDK symbol source pipeline",
  .tags(.extraction, .indexing),
  .enabled(
    if: ProcessInfo.processInfo.environment["RUN_EXTRACTION_TESTS"] != nil
      && SDKDiscovery.latestXcode() != nil
  )
)
struct SDKSymbolSourcePipelineTests {
  @Test("A single module extracts end-to-end")
  func extractsASingleModuleEndToEnd() async throws {
    let xcode = try #require(SDKDiscovery.latestXcode())
    let source = SDKSymbolSource(xcode: xcode)

    let framework = try #require(
      try await source.makeFramework(named: "PencilKit")
    )
    #expect(framework.moduleName == "PencilKit")
    #expect(
      framework.symbols.contains {
        $0.title == "PKStroke.RenderState"
          && $0.introduced[.iOS] == SemanticVersion(major: 27)
      }
    )
  }
}
