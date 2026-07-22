import Foundation

/// A failure encountered while managing the Xcode registry.
public enum XcodeRegistryError: Error, LocalizedError, Sendable, Equatable {
  /// The bundle at the given URL is not a usable Xcode.
  case notAnXcode(URL)

  /// A description suitable for showing to a person.
  public var errorDescription: String? {
    switch self {
    case let .notAnXcode(url):
      "\(url.path(percentEncoded: false)) is not a usable Xcode."
    }
  }
}
