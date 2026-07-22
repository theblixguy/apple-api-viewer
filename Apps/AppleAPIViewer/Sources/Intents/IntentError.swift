import AppIntents

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
  case noIndex
  case unknownFramework(String)

  var localizedStringResource: LocalizedStringResource {
    switch self {
    case .noIndex:
      "No API index is available. Open Apple API Viewer to build one."
    case let .unknownFramework(name):
      "No framework named \(name) is in the index."
    }
  }
}
