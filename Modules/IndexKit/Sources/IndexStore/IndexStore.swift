import Dependencies
import Foundation
import SQLiteData // Re-exports GRDB connection types and the #sql macro, and provides defaultDatabase.

/// SQLite-backed store for the extracted symbol index, with FTS5 search.
///
/// Every framework belongs to one `Source`, one per indexed Xcode build, and
/// several sources' indexes coexist in the store.
public struct IndexStore: Sendable {
  @Dependency(\.defaultDatabase) var database

  private static let schemaVersion = 5

  /// The default cap on search results, applied once after ranking across
  /// the whole selection.
  public static let defaultSearchLimit = 200

  /// Creates a store that reads its connection from the `defaultDatabase`
  /// dependency.
  ///
  /// Call ``bootstrap(at:)`` once at startup to install one.
  public init() {}

  // MARK: - Database construction

  static func makeDatabase(at url: URL) throws -> any DatabaseWriter {
    // The app, its extensions, and the CLI share this database across
    // processes, and the final save of a full build holds the write lock
    // for tens of seconds. With this timeout, an overlapping writer waits
    // instead of failing with SQLITE_BUSY.
    var configuration = Configuration()
    configuration.busyMode = .timeout(30)
    let pool = try DatabasePool(
      path: url.path(percentEncoded: false), configuration: configuration
    )
    try setUpSchema(pool)
    return pool
  }

  /// Returns an ephemeral in-memory database, for tests and previews.
  ///
  /// - Returns: A new in-memory database.
  /// - Throws: An error if the database cannot be created.
  public static func makeInMemoryDatabase() throws -> any DatabaseWriter {
    let queue = try DatabaseQueue()
    try setUpSchema(queue)
    return queue
  }

  /// How the index database was opened by ``bootstrap(at:)``.
  public enum StorageMode: Sendable, Equatable {
    /// The on-disk database opened normally.
    case persistent
    /// The on-disk database could not be opened, so a transient in-memory
    /// store is in use. The index does not persist across launches.
    case inMemoryFallback
  }

  /// Creates the database on disk at `url`, falling back to an in-memory
  /// database, and installs it as the `defaultDatabase` dependency.
  ///
  /// Call once at app startup, before any ``IndexStore`` is used.
  ///
  /// - Parameter url: The database file's URL, or `nil` to use an in-memory
  ///   database.
  /// - Returns: How the database was opened.
  public static func bootstrap(at url: URL?) -> StorageMode {
    if let url, let database = try? makeDatabase(at: url) {
      prepareDependencies { $0.defaultDatabase = database }
      return .persistent
    }
    do {
      let database = try makeInMemoryDatabase()
      prepareDependencies { $0.defaultDatabase = database }
      return .inMemoryFallback
    } catch {
      preconditionFailure("Couldn't open an in-memory index database: \(error)")
    }
  }

  private static func setUpSchema(_ writer: some DatabaseWriter) throws {
    try writer.write { db in
      let installedVersion =
        try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
      if installedVersion != schemaVersion {
        for table in [
          "availability_staging", "symbol_staging", "framework_staging",
          "source_staging", "availability", "introduced", "symbol_fts",
          "symbol", "framework", "source",
        ] {
          try db.execute(sql: "DROP TABLE IF EXISTS \(table)")
        }
      }
      // The `ON DELETE CASCADE` relationships below depend on foreign keys
      // being enforced. GRDB enables `PRAGMA foreign_keys = ON` by default on
      // every connection. This lets `replaceFramework` delete a framework row
      // and cascade its symbol and availability rows away.
      try db.execute(
        sql: """
        CREATE TABLE IF NOT EXISTS source (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            displayName TEXT NOT NULL,
            signature TEXT
        );
        CREATE TABLE IF NOT EXISTS framework (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            moduleName TEXT NOT NULL,
            sourceId TEXT NOT NULL REFERENCES source(id) ON DELETE CASCADE,
            UNIQUE (moduleName, sourceId)
        );
        -- Symbols key on `frameworkId` and `usr`, not the USR alone. Each
        -- source is one indexed Xcode build, and several sources can index
        -- the same declarations side by side.
        CREATE TABLE IF NOT EXISTS symbol (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usr TEXT NOT NULL,
            frameworkId INTEGER NOT NULL REFERENCES framework(id) ON DELETE CASCADE,
            title TEXT NOT NULL,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            pathComponents TEXT NOT NULL,
            parentUSR TEXT,
            isDeprecated INTEGER NOT NULL,
            summary TEXT,
            UNIQUE (frameworkId, usr)
        );
        -- This encodes generalized availability. `domainKind` and
        -- `domainValue` together encode an `AvailabilityDomain`. For
        -- example, they store 'platform' and 'iOS'. The version is null
        -- when a source records presence without one.
        CREATE TABLE IF NOT EXISTS availability (
            symbolId INTEGER NOT NULL REFERENCES symbol(id) ON DELETE CASCADE,
            domainKind TEXT NOT NULL,
            domainValue TEXT NOT NULL,
            major INTEGER,
            minor INTEGER,
            patch INTEGER,
            PRIMARY KEY (symbolId, domainKind, domainValue)
        );
        CREATE INDEX IF NOT EXISTS idx_availability_release ON availability(domainKind, domainValue, major, minor);
        CREATE VIRTUAL TABLE IF NOT EXISTS symbol_fts USING fts5(symbolId UNINDEXED, searchText);
        """
      )
      try db.execute(sql: "PRAGMA user_version = \(schemaVersion)")
    }
  }
}
