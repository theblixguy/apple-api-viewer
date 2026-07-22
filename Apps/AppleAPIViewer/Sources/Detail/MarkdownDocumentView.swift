import MarkdownEngine
import MarkdownEngineCodeBlocks
import SwiftUI

struct MarkdownDocumentView: View {
  private let markdown: String
  private let documentId: String
  private let header: AnyView?

  @Environment(\.openURL) private var openURL

  init(markdown: String, documentId: String) {
    self.markdown = markdown
    self.documentId = documentId
    header = nil
  }

  init(
    markdown: String, documentId: String, @ViewBuilder header: () -> some View
  ) {
    self.markdown = markdown
    self.documentId = documentId
    self.header = AnyView(header())
  }

  var body: some View {
    NativeTextViewWrapper(
      text: .constant(markdown),
      configuration: Self.configuration,
      documentId: documentId,
      isEditable: false,
      onLinkClick: { link in
        guard let url = URL(string: link),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return }
        openURL(url)
      },
      header: header
    )
  }

  private static let configuration: MarkdownEditorConfiguration = {
    var configuration = MarkdownEditorConfiguration.default
    configuration.services = MarkdownEditorServices(
      syntaxHighlighter: HighlighterSwiftBridge()
    )
    // Doc comments use GitHub flavored markdown, which includes ~~text~~.
    // Highlight stays unregistered because == in API prose is an operator,
    // not markup.
    configuration.extensions = [StrikethroughExtension()]
    configuration.textInsets = TextInsets(
      horizontal: Spacing.xxLarge, vertical: Spacing.medium
    )
    return configuration
  }()
}

#Preview("Markdown Document") {
  MarkdownDocumentView(
    markdown: """
    Draws a stroke using the supplied `PKInk` and the current `RenderState`.

    Encode the value using `Codable` to persist all stored information:

    ```swift
    let data = try JSONEncoder().encode(stroke)
    let restored = try JSONDecoder().decode(PKStroke.self, from: data)
    ```

    Encoding and then decoding produces an identical value.
    """,
    documentId: "preview"
  )
  .frame(width: 460, height: 420)
}
