import Foundation

/// A cross-process lock that serializes full index builds on one database.
///
/// The app and the command line tool share one database file. If two
/// staged builds run at the same time, they destroy each other's staging
/// tables, so each build holds this lock from start to commit. The lock
/// releases when the value is destroyed, and the kernel releases it when
/// the process exits for any reason.
public struct IndexBuildLock: ~Copyable, Sendable {
  private let descriptor: Int32

  /// Acquires the build lock for the database at `databaseURL`.
  ///
  /// - Parameter databaseURL: The index database the build writes to.
  /// - Throws: ``IndexBuildInProgressError`` when another build holds the
  ///   lock, or an error if the lock file cannot be created.
  public init(databaseURL: URL) throws {
    let path = databaseURL.path(percentEncoded: false) + ".build-lock"
    // O_CLOEXEC keeps the descriptor out of extractor subprocesses. A
    // child process cannot keep the lock alive after this process dies.
    let descriptor = open(path, O_CREAT | O_RDWR | O_CLOEXEC, 0o644)
    guard descriptor >= 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
      close(descriptor)
      throw IndexBuildInProgressError()
    }
    self.descriptor = descriptor
  }

  deinit {
    Self.unlock(descriptor)
  }

  /// Releases the lock before the value is destroyed.
  public consuming func release() {
    Self.unlock(descriptor)
    discard self
  }

  private static func unlock(_ descriptor: Int32) {
    flock(descriptor, LOCK_UN)
    close(descriptor)
  }
}
