import CoreModel
import Foundation
import SQLiteData
import SymbolGraphIndex

extension IndexStore {
  /// Atomically replaces one source's index with `frameworks` and records its
  /// `signature`, leaving other sources' indexes untouched.
  ///
  /// - Parameters:
  ///   - signature: The signature to record for the replaced index.
  ///   - source: The source whose index to replace.
  ///   - frameworks: The frameworks to store as the new index.
  /// - Throws: `CancellationError` if the task is canceled mid-write, which
  ///   leaves the previous index in place, or a database error.
  public func replaceIndex(
    signature: String, source: Source, frameworks: [FrameworkIndex]
  ) async throws {
    try await replaceIndex(
      bySource: [source: frameworks], signatures: [source.id: signature]
    )
  }

  /// Atomically replaces several sources' indexes at once, recording each
  /// source's signature and leaving sources not in `contents` untouched.
  ///
  /// Frameworks are staged first, so the live index stays readable throughout
  /// and only the final commit swaps the result in.
  ///
  /// - Parameters:
  ///   - contents: The frameworks to store, keyed by source.
  ///   - signatures: The signature to record for each replaced source.
  /// - Throws: `CancellationError` if the task is canceled mid-write, which
  ///   leaves the previous index in place, or a database error.
  public func replaceIndex(
    bySource contents: [Source: [FrameworkIndex]],
    signatures: [Source.ID: String]
  ) async throws {
    try await beginStagedIndex()
    for (source, frameworks) in contents {
      try await stageSource(source)
      for framework in frameworks {
        try Task.checkCancellation()
        try await stageFramework(framework, source: source)
      }
    }
    try await commitStagedIndex(signatures: signatures)
  }

  // MARK: - Staged builds

  // An interrupted build can leave staging behind, so the tables drop and
  // recreate. The live index stays readable throughout the staged build.
  package func beginStagedIndex() async throws {
    try await database.write { db in
      try db.execute(
        sql: """
        DROP TABLE IF EXISTS availability_staging;
        DROP TABLE IF EXISTS symbol_staging;
        DROP TABLE IF EXISTS framework_staging;
        DROP TABLE IF EXISTS source_staging;
        CREATE TABLE source_staging (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            displayName TEXT NOT NULL
        );
        CREATE TABLE framework_staging (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            moduleName TEXT NOT NULL,
            sourceId TEXT NOT NULL,
            UNIQUE (moduleName, sourceId)
        );
        CREATE TABLE symbol_staging (
            frameworkId INTEGER NOT NULL,
            usr TEXT NOT NULL,
            title TEXT NOT NULL,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            pathComponents TEXT NOT NULL,
            parentUSR TEXT,
            isDeprecated INTEGER NOT NULL,
            summary TEXT,
            searchText TEXT NOT NULL,
            PRIMARY KEY (frameworkId, usr)
        );
        CREATE TABLE availability_staging (
            frameworkId INTEGER NOT NULL,
            symbolUSR TEXT NOT NULL,
            domainKind TEXT NOT NULL,
            domainValue TEXT NOT NULL,
            major INTEGER,
            minor INTEGER,
            patch INTEGER,
            PRIMARY KEY (frameworkId, symbolUSR, domainKind, domainValue)
        );
        """
      )
    }
  }

  package func stageSource(_ source: Source) async throws {
    try await database.write { db in
      try Self.insertStagedSource(source, into: db)
    }
  }

  // Staging the same module again merges by USR, and the earlier rows win.
  // The multi-SDK merge in `SDKSymbolSource` depends on this order.
  package func stageFramework(
    _ framework: FrameworkIndex, source: Source
  ) async throws {
    try await database.write { db in
      try Self.insertStagedSource(source, into: db)
      try FrameworkStagingRecord
        .insert {
          ($0.moduleName, $0.sourceId)
        } values: {
          (framework.moduleName, source.id)
        } onConflictDoUpdate: { _, _ in
        }
        .execute(db)
      let stagedFrameworkId =
        try FrameworkStagingRecord
          .where {
            $0.moduleName.eq(framework.moduleName) && $0.sourceId.eq(source.id)
          }
          .select { $0.id }
          .fetchOne(db)
      guard let frameworkId = stagedFrameworkId else { return }

      let encoder = JSONEncoder()
      let symbolsByUSR = Dictionary(
        framework.symbols.map { ($0.usr, $0) },
        uniquingKeysWith: { first, _ in first }
      )
      let rows: [SymbolStagingRecord] = try framework.symbols.map { symbol in
        SymbolStagingRecord(
          frameworkId: frameworkId,
          usr: symbol.usr,
          title: symbol.title,
          name: symbol.name,
          kind: symbol.kind.rawValue,
          pathComponents: String(
            decoding: try encoder.encode(symbol.pathComponents), as: UTF8.self
          ),
          parentUSR: symbol.parentUSR,
          isDeprecated: symbol.isDeprecated,
          summary: symbol.summary,
          searchText: Self.searchText(for: symbol)
        )
      }
      for chunk in Self.insertChunks(of: rows) {
        // Staging the same symbol again is ignored, so the returned USRs
        // are the rows this call actually added. Only those get
        // availability rows.
        let insertedUSRs =
          try SymbolStagingRecord
            .insert {
              for row in chunk {
                row
              }
            } onConflictDoUpdate: { _, _ in
            }
            .returning { $0.usr }
            .fetchAll(db)

        let availabilityRows: [AvailabilityStagingRecord] = insertedUSRs
          .flatMap { usr in
            (symbolsByUSR[usr]?.availability ?? []).map { availability in
              AvailabilityStagingRecord(
                frameworkId: frameworkId,
                symbolUSR: usr,
                domainKind: Self.storageDomain(availability.domain).kind,
                domainValue: Self.storageDomain(availability.domain).value,
                major: availability.introduced?.major,
                minor: availability.introduced?.minor,
                patch: availability.introduced?.patch
              )
            }
          }
        for availabilityChunk in Self.insertChunks(of: availabilityRows) {
          try AvailabilityStagingRecord
            .insert {
              for row in availabilityChunk {
                row
              }
            }
            .execute(db)
        }
      }
    }
  }

  // One transaction swaps the staged build in, so readers never see a
  // partial index.
  package func commitStagedIndex(signatures: [Source.ID: String]) async throws {
    try await database.write { db in
      try Task.checkCancellation()
      try #sql(
        """
        DELETE FROM symbol_fts WHERE symbolId IN (
            SELECT s.id FROM symbol s JOIN framework f ON s.frameworkId = f.id
            WHERE f.sourceId IN (SELECT id FROM source_staging)
        )
        """
      ).execute(db)
      try FrameworkRecord
        .where { $0.sourceId.in(SourceStagingRecord.select { $0.id }) }
        .delete()
        .execute(db)
      let stagedSources = try SourceStagingRecord.all.fetchAll(db)
      if !stagedSources.isEmpty {
        try SourceRecord
          .insert {
            ($0.id, $0.kind, $0.displayName)
          } values: {
            for staged in stagedSources {
              (staged.id, staged.kind, staged.displayName)
            }
          } onConflictDoUpdate: { row, excluded in
            row.displayName = excluded.displayName
          }
          .execute(db)
      }

      try Task.checkCancellation()
      try FrameworkRecord
        .insert {
          ($0.moduleName, $0.sourceId)
        } select: {
          FrameworkStagingRecord
            .order { ($0.moduleName, $0.sourceId) }
            .select { ($0.moduleName, $0.sourceId) }
        }
        .execute(db)
      try SymbolRecord
        .insert {
          (
            $0.usr, $0.frameworkId, $0.title, $0.name, $0.kind,
            $0.pathComponents, $0.parentUSR, $0.isDeprecated, $0.summary
          )
        } select: {
          SymbolStagingRecord
            .join(FrameworkStagingRecord.all) { $0.frameworkId.eq($1.id) }
            .join(FrameworkRecord.all) {
              $1.moduleName.eq($2.moduleName) && $1.sourceId.eq($2.sourceId)
            }
            .select { staged, _, framework in
              (
                staged.usr, framework.id, staged.title, staged.name,
                staged.kind, staged.pathComponents, staged.parentUSR,
                staged.isDeprecated, staged.summary
              )
            }
        }
        .execute(db)

      try Task.checkCancellation()
      try AvailabilityRecord
        .insert {
          (
            $0.symbolId, $0.domainKind, $0.domainValue, $0.major, $0.minor,
            $0.patch
          )
        } select: {
          AvailabilityStagingRecord
            .join(FrameworkStagingRecord.all) { $0.frameworkId.eq($1.id) }
            .join(FrameworkRecord.all) {
              $1.moduleName.eq($2.moduleName) && $1.sourceId.eq($2.sourceId)
            }
            .join(SymbolRecord.all) {
              $3.frameworkId.eq($2.id) && $3.usr.eq($0.symbolUSR)
            }
            .select { staged, _, _, symbol in
              (
                symbol.id, staged.domainKind, staged.domainValue, staged.major,
                staged.minor, staged.patch
              )
            }
        }
        .execute(db)

      try Task.checkCancellation()
      try #sql(
        """
        INSERT INTO symbol_fts (symbolId, searchText)
        SELECT s.id, ss.searchText
        FROM symbol_staging ss
        JOIN framework_staging fs ON fs.id = ss.frameworkId
        JOIN framework f ON f.moduleName = fs.moduleName AND f.sourceId = fs.sourceId
        JOIN symbol s ON s.frameworkId = f.id AND s.usr = ss.usr
        """
      ).execute(db)

      for (sourceID, signature) in signatures {
        try SourceRecord
          .where { $0.id.eq(sourceID) }
          .update { $0.signature = #bind(signature) }
          .execute(db)
      }
      try db.execute(
        sql: """
        DROP TABLE availability_staging;
        DROP TABLE symbol_staging;
        DROP TABLE framework_staging;
        DROP TABLE source_staging;
        """
      )
    }
  }

  // MARK: - Removal

  // Deleted rows do not return space to the file system. Call `compact()`
  // afterward to return it.
  package func removeSource(_ id: Source.ID) async throws {
    try await database.write { db in
      try #sql(
        """
        DELETE FROM symbol_fts WHERE symbolId IN (
            SELECT s.id FROM symbol s JOIN framework f ON s.frameworkId = f.id
            WHERE f.sourceId = \(bind: id)
        )
        """
      ).execute(db)
      try SourceRecord.where { $0.id.eq(id) }.delete().execute(db)
    }
  }

  // FTS rows are not covered by the foreign-key cascade, so the FTS table
  // is cleared explicitly.
  package func removeAllSources() async throws -> Bool {
    try await database.write { db -> Bool in
      let sources = try SourceRecord.select { $0.id }.fetchAll(db)
      guard !sources.isEmpty else { return false }
      try #sql("DELETE FROM symbol_fts").execute(db)
      try SourceRecord.all.delete().execute(db)
      return true
    }
  }

  // VACUUM rewrites the whole database file, which can be slow for a large
  // index.
  package func compact() async throws {
    try await database.writeWithoutTransaction { db in
      try db.execute(sql: "VACUUM")
    }
  }

  /// Replaces a single framework's rows in place, leaving the rest of the index
  /// and its source's signature untouched.
  ///
  /// - Parameters:
  ///   - framework: The framework to store.
  ///   - source: The source the framework belongs to.
  /// - Throws: An error if the underlying database write fails.
  public func replaceFramework(
    _ framework: FrameworkIndex, source: Source
  ) async throws {
    let name = framework.moduleName
    let sourceId = source.id
    try await database.write { db in
      // FTS rows are not covered by the foreign-key cascade, so they must
      // clear first, while the symbols that locate them still exist.
      try #sql(
        """
        DELETE FROM symbol_fts WHERE symbolId IN (
            SELECT s.id FROM symbol s JOIN framework f ON s.frameworkId = f.id
            WHERE f.moduleName = \(bind: name) AND f.sourceId = \(
              bind: sourceId
            )
        )
        """
      ).execute(db)
      try FrameworkRecord
        .where { $0.moduleName.eq(name) && $0.sourceId.eq(sourceId) }
        .delete()
        .execute(db)
      try Self.insertSource(source, into: db)
      try Self.insert(
        framework: framework, sourceId: sourceId, into: db,
        encoder: JSONEncoder()
      )
    }
  }

  private static func insertStagedSource(
    _ source: Source, into db: Database
  ) throws {
    try SourceStagingRecord
      .insert {
        SourceStagingRecord(
          id: source.id,
          kind: source.kind.rawValue,
          displayName: source.displayName
        )
      } onConflictDoUpdate: { _, _ in
      }
      .execute(db)
  }

  private static func insertSource(_ source: Source, into db: Database) throws {
    // The conflict clause does nothing, never a replace. A replace would
    // delete the conflicting row first, and `ON DELETE CASCADE` would
    // then wipe the whole source through framework, symbol, and
    // availability. `replaceFramework` needs the existing source and its
    // frameworks intact.
    try SourceRecord
      .insert {
        ($0.id, $0.kind, $0.displayName)
      } values: {
        (source.id, source.kind.rawValue, source.displayName)
      } onConflictDoUpdate: { _, _ in
      }
      .execute(db)
  }

  private static func insert(
    framework: FrameworkIndex, sourceId: String, into db: Database,
    encoder: JSONEncoder
  ) throws {
    let insertedFrameworkId =
      try FrameworkRecord
        .insert {
          FrameworkRecord.Draft(
            moduleName: framework.moduleName, sourceId: sourceId
          )
        }
        .returning { $0.id }
        .fetchOne(db)
    guard let frameworkId = insertedFrameworkId else { return }

    let symbolsByUSR = Dictionary(
      framework.symbols.map { ($0.usr, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    let drafts: [SymbolRecord.Draft] = try framework.symbols.map { symbol in
      SymbolRecord.Draft(
        usr: symbol.usr,
        frameworkId: frameworkId,
        title: symbol.title,
        name: symbol.name,
        kind: symbol.kind.rawValue,
        pathComponents: String(
          decoding: try encoder.encode(symbol.pathComponents), as: UTF8.self
        ),
        parentUSR: symbol.parentUSR,
        isDeprecated: symbol.isDeprecated,
        summary: symbol.summary
      )
    }
    for chunk in Self.insertChunks(of: drafts) {
      let inserted =
        try SymbolRecord
          .insert {
            for draft in chunk {
              draft
            }
          } onConflictDoUpdate: { _, _ in
          }
          .returning { ($0.id, $0.usr) }
          .fetchAll(db)

      var availabilityRows: [AvailabilityRecord] = []
      var searchRows: [SymbolFTSRecord] = []
      for (symbolId, usr) in inserted {
        guard let symbol = symbolsByUSR[usr] else { continue }
        for availability in symbol.availability {
          availabilityRows.append(
            AvailabilityRecord(
              symbolId: symbolId,
              domainKind: Self.storageDomain(availability.domain).kind,
              domainValue: Self.storageDomain(availability.domain).value,
              major: availability.introduced?.major,
              minor: availability.introduced?.minor,
              patch: availability.introduced?.patch
            )
          )
        }
        searchRows.append(
          SymbolFTSRecord(
            symbolId: symbolId, searchText: Self.searchText(for: symbol)
          )
        )
      }
      for rows in Self.insertChunks(of: availabilityRows) {
        try AvailabilityRecord
          .insert {
            for row in rows {
              row
            }
          }
          .execute(db)
      }
      for rows in Self.insertChunks(of: searchRows) {
        try SymbolFTSRecord
          .insert {
            for row in rows {
              row
            }
          }
          .execute(db)
      }
    }
  }

  // SQLite caps the bound variables in one statement, so batched inserts
  // stay in chunks well under that limit.
  private static let insertChunkRowCount = 500

  private static func insertChunks<Element>(of elements: [Element])
    -> [[Element]]
  {
    stride(from: 0, to: elements.count, by: insertChunkRowCount).map {
      Array(elements[$0..<min($0 + insertChunkRowCount, elements.count)])
    }
  }

  private static func storageDomain(_ domain: AvailabilityDomain) -> (
    kind: String, value: String
  ) {
    switch domain {
    case let .platform(platform): ("platform", platform.rawValue)
    case let .package(name): ("package", name)
    }
  }
}
