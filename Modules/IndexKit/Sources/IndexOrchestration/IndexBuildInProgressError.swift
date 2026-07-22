import Foundation

/// An error that indicates another process already holds the build lock.
public struct IndexBuildInProgressError: Error, LocalizedError {
  /// The user-facing description of the error.
  public var errorDescription: String? {
    String(
      localized:
      "Another index build is already running. Wait for it to finish, then try again."
    )
  }
}
