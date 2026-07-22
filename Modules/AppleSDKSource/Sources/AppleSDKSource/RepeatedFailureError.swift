import Foundation

/// An error that indicates many modules in a row failed to extract, a
/// sign of a systemic cause rather than broken modules.
public struct RepeatedFailureError: Error, LocalizedError, Sendable {
  /// The number of modules that failed in a row.
  public let failureCount: Int

  /// The user-facing description of the error.
  public var errorDescription: String? {
    String(
      localized: """
      The build stopped because \(failureCount) modules in a row failed to \
      extract. Check the free disk space and the selected Xcode, then build \
      the index again.
      """
    )
  }
}
