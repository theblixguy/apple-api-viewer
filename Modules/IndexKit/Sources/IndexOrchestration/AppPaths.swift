import Foundation

/// Shared filesystem locations for the index.
public enum AppPaths {
  /// Returns the on-disk SQLite index file's URL under Application Support,
  /// creating the enclosing directory if it does not already exist.
  ///
  /// - Returns: The URL of the index database file.
  /// - Throws: An error if the Application Support directory cannot be
  ///   located or created.
  public static func databaseURL() throws -> URL {
    let base = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true
    )
    let directory = base.appending(
      path: "Apple API Viewer", directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true
    )
    return directory.appending(path: "index.sqlite")
  }
}
