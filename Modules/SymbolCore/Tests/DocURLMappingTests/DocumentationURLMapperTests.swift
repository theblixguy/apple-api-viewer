import DocURLMapping
import Foundation
import Testing

@Suite("Documentation URL mapper", .tags(.documentation))
struct DocumentationURLMapperTests {
  @Test("Nested symbol path builds a documentation page URL")
  func buildsNestedSymbolPage() {
    #expect(
      DocumentationURLMapper.documentationURL(
        framework: "PencilKit", pathComponents: ["PKStroke", "RenderState"]
      )
      .absoluteString
      == "https://developer.apple.com/documentation/pencilkit/pkstroke/renderstate"
    )
  }

  @Test("Top-level types build documentation page URLs")
  func buildsTopLevelTypePages() {
    #expect(
      DocumentationURLMapper.documentationURL(
        framework: "UIKit", pathComponents: ["UIView"]
      )
      .absoluteString
      == "https://developer.apple.com/documentation/uikit/uiview"
    )
    #expect(
      DocumentationURLMapper.documentationURL(
        framework: "SwiftUI", pathComponents: ["View"]
      )
      .absoluteString
      == "https://developer.apple.com/documentation/swiftui/view"
    )
  }

  @Test("Slash inside a path component is percent-encoded")
  func percentEncodesASlashInsideAPathComponent() {
    #expect(
      DocumentationURLMapper.documentationURL(
        framework: "Swift", pathComponents: ["Double", "/(_:_:)"]
      )
      .absoluteString
      == "https://developer.apple.com/documentation/swift/double/%2F(_:_:)"
    )
  }

  @Test("Symbol path builds a render JSON endpoint URL")
  func buildsRenderJSONEndpoint() {
    #expect(
      DocumentationURLMapper.renderJSONURL(
        framework: "PencilKit", pathComponents: ["PKStroke", "RenderState"]
      )
      .absoluteString
      == "https://developer.apple.com/tutorials/data/documentation/pencilkit/pkstroke/renderstate.json"
    )
  }
}
