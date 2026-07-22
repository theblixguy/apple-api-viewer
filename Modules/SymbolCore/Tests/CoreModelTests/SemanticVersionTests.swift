import CoreModel
import Testing

@Suite("Semantic version", .tags(.versioning))
struct SemanticVersionTests {
  @Test(
    "Dotted strings parse into major, minor, and patch",
    arguments: [
      ("27", SemanticVersion(major: 27)),
      ("27.0", SemanticVersion(major: 27, minor: 0)),
      ("26.5", SemanticVersion(major: 26, minor: 5)),
      ("16.4.1", SemanticVersion(major: 16, minor: 4, patch: 1)),
      (" 27.0 ", SemanticVersion(major: 27, minor: 0)),
    ]
  )
  func parsesDottedStrings(string: String, expected: SemanticVersion) {
    #expect(SemanticVersion(string) == expected)
  }

  @Test(
    "Invalid strings fail to parse",
    arguments: ["", "abc", "27.x", "1.2.3.4", "-1.0"]
  )
  func rejectsInvalidStrings(string: String) {
    #expect(SemanticVersion(string) == nil)
  }

  @Test("Versions order by major, minor, and patch")
  func ordersByComponent() {
    #expect(
      SemanticVersion(major: 26, minor: 5)
        < SemanticVersion(major: 27, minor: 0)
    )
    #expect(
      SemanticVersion(major: 27, minor: 0)
        < SemanticVersion(major: 27, minor: 1)
    )
    #expect(
      SemanticVersion(major: 27, minor: 0, patch: 0)
        < SemanticVersion(major: 27, minor: 0, patch: 1)
    )
  }

  @Test("Same release ignores patch differences")
  func sameReleaseIgnoresPatch() {
    #expect(
      SemanticVersion(major: 27, minor: 0).isSameRelease(
        as: SemanticVersion(major: 27, minor: 0, patch: 3)
      )
    )
    #expect(
      !SemanticVersion(major: 27, minor: 0).isSameRelease(
        as: SemanticVersion(major: 27, minor: 1)
      )
    )
    #expect(
      !SemanticVersion(major: 26, minor: 5).isSameRelease(
        as: SemanticVersion(major: 27, minor: 5)
      )
    )
  }

  @Test("Description drops a zero patch component")
  func descriptionDropsZeroPatch() {
    #expect(SemanticVersion(major: 27, minor: 0).description == "27.0")
    #expect(
      SemanticVersion(major: 16, minor: 4, patch: 1).description == "16.4.1"
    )
  }
}
