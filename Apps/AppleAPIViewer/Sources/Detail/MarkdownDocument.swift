import SwiftUI
import UniformTypeIdentifiers

struct MarkdownDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.markdownText]

  var text: String

  init(text: String) {
    self.text = text
  }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents else {
      throw CocoaError(.fileReadCorruptFile)
    }
    text = String(decoding: data, as: UTF8.self)
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: Data(text.utf8))
  }
}

extension UTType {
  nonisolated static let markdownText =
    UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
}
