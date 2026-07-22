import CoreModel
import Testing

@Suite("Apple platform", .tags(.versioning))
struct ApplePlatformTests {
  @Test(
    "Known availability domains map to their Apple platform",
    arguments: [
      ("iOS", ApplePlatform.iOS),
      ("iPadOS", .iOS),
      ("macOS", .macOS),
      ("visionOS", .visionOS),
      ("watchOS", .watchOS),
      ("tvOS", .tvOS),
    ]
  )
  func mapsKnownAvailabilityDomains(domain: String, platform: ApplePlatform) {
    #expect(ApplePlatform(availabilityDomain: domain) == platform)
  }

  @Test(
    "Unrecognized domains are ignored",
    arguments: ["macCatalyst", "iOSAppExtension", "Swift"]
  )
  func ignoresUnrecognizedDomains(domain: String) {
    #expect(ApplePlatform(availabilityDomain: domain) == nil)
  }

  @Test(
    "Platforms map to their target triple OS token",
    arguments: [
      (ApplePlatform.iOS, "ios"),
      (.macOS, "macos"),
      (.visionOS, "xros"),
    ]
  )
  func targetTripleOSTokens(platform: ApplePlatform, token: String) {
    #expect(platform.targetTripleOS == token)
  }

  @Test(
    "Availability domain round-trips through the platform",
    arguments: ApplePlatform.allCases
  )
  func availabilityDomainRoundTrips(_ platform: ApplePlatform) {
    #expect(
      ApplePlatform(availabilityDomain: platform.availabilityDomain)
        == platform
    )
  }

  @Test("Platforms order alphabetically by name")
  func ordersAlphabetically() {
    #expect(
      ApplePlatform.allCases.sorted() == [
        .iOS, .macOS, .tvOS, .visionOS, .watchOS,
      ]
    )
  }
}
