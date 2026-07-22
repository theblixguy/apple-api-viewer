import CoreModel
import Foundation
import Testing
@testable import SDKDiscovery

@Suite("SDK discovery parsing", .tags(.extraction, .xcodes))
struct SDKDiscoveryParsingTests {
  @Test(
    "Canonical SDK names map to platforms",
    arguments: [
      ("iphoneos27.0", ApplePlatform.iOS),
      ("macosx27.0", .macOS),
      ("macosx", .macOS),
      ("appletvos18.0", .tvOS),
      ("watchos11.0", .watchOS),
      ("xros2.0", .visionOS),
    ]
  )
  func mapsCanonicalNamesToPlatforms(name: String, platform: ApplePlatform) {
    #expect(SDKDiscovery.platform(forCanonicalName: name) == platform)
  }

  @Test(
    "Simulator and DriverKit SDKs map to no platform",
    arguments: ["iphonesimulator27.0", "appletvsimulator18.0", "driverkit24.0"]
  )
  func excludesSimulatorAndCatalystSDKs(name: String) {
    #expect(SDKDiscovery.platform(forCanonicalName: name) == nil)
  }

  @Test("Xcode version plist decodes into short version and build")
  func decodesXcodeVersionPlist() throws {
    let plist: [String: Any] = [
      "CFBundleShortVersionString": "27.0",
      "ProductBuildVersion": "27A5194q",
      "CFBundleVersion": "25183.29.15",
    ]
    let data = try PropertyListSerialization.data(
      fromPropertyList: plist, format: .xml, options: 0
    )
    let info = try PropertyListDecoder().decode(
      SDKDiscovery.XcodeVersionInfo.self, from: data
    )
    #expect(info.shortVersion == "27.0")
    #expect(info.build == "27A5194q")
  }

  @Test("SDK settings plist decodes into version and canonical name")
  func decodesSDKSettingsPlist() throws {
    let plist: [String: Any] = [
      "Version": "27.0",
      "CanonicalName": "iphoneos27.0",
      "DisplayName": "iOS 27.0",
    ]
    let data = try PropertyListSerialization.data(
      fromPropertyList: plist, format: .xml, options: 0
    )
    let info = try PropertyListDecoder().decode(
      SDKDiscovery.SDKSettingsInfo.self, from: data
    )
    #expect(info.version == "27.0")
    #expect(info.canonicalName == "iphoneos27.0")
  }

  @Test("Non-Xcode bundle returns nil")
  func returnsNilForANonXcodeBundle() {
    #expect(
      SDKDiscovery.xcode(at: URL(filePath: "/Applications/NotXcode.app")) == nil
    )
  }
}

@Suite(
  "SDK discovery integration",
  .tags(.extraction, .xcodes),
  .enabled(if: !SDKDiscovery.installedXcodes().isEmpty)
)
struct SDKDiscoveryIntegrationTests {
  @Test("Latest Xcode reports SDKs for iOS and macOS")
  func findsLatestXcodeAndItsSDKs() throws {
    let latest = try #require(SDKDiscovery.latestXcode())
    #expect(latest.version.major >= 26)
    #expect(
      FileManager.default.fileExists(atPath: latest.toolchainSwiftURL.path)
    )

    let sdks = SDKDiscovery.sdks(in: latest)
    let platforms = Set(sdks.map(\.platform))
    #expect(platforms.contains(.iOS))
    #expect(platforms.contains(.macOS))
    #expect(sdks.count == platforms.count)
  }

  @Test("Rereading Xcode at its bundle path returns the same build")
  func rereadsXcodeAtItsBundlePath() throws {
    let latest = try #require(SDKDiscovery.latestXcode())
    #expect(
      SDKDiscovery.xcode(at: latest.applicationURL)?.build == latest.build
    )
  }

  @Test("System-selected Xcode resolves to an app bundle")
  func resolvesSystemSelectedXcodeToABundle() throws {
    let system = try #require(SDKDiscovery.systemSelectedXcode())
    #expect(system.applicationURL.pathExtension == "app")
    #expect(
      FileManager.default.fileExists(atPath: system.toolchainSwiftURL.path)
    )
  }
}
