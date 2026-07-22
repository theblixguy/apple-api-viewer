import ArgumentParser
import Foundation

struct ErrorOutput: Encodable {
  struct Detail: Encodable {
    let code: String
    let message: String
  }

  let error: Detail
}

// These codes extend ArgumentParser's own usage-error codes.
enum ExitStatus {
  static let noIndex: Int32 = 3
  static let noXcode: Int32 = 4
  static let notFound: Int32 = 5
  static let notRemovable: Int32 = 6
  static let modelUnavailable: Int32 = 7
  static let storageUnavailable: Int32 = 8
  static let buildInProgress: Int32 = 9
}

func fail(
  _ message: String, code: Int32, name: String, format: OutputFormat
) -> ExitCode {
  let line =
    switch format {
    case .text: "Error: \(message)"
    case .json:
      JSONLine.string(ErrorOutput(error: .init(code: name, message: message)))
    }
  FileHandle.standardError.write(Data((line + "\n").utf8))
  return ExitCode(code)
}
