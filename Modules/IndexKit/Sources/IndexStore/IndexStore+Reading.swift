import CoreModel
import Foundation
import SQLiteData
import SymbolGraphIndex

extension IndexStore {
  /// Returns the signature recorded when `source`'s index was built, or `nil`
  /// when that source has no index yet.
  ///
  /// - Parameter source: The source whose index is read.
  /// - Returns: The signature recorded when `source`'s index was built, or
  ///   `nil` when that source has no index yet.
  /// - Throws: An error if the underlying database read fails.
  public func signature(forSource source: Source.ID) async throws -> String? {
    try await database.read { db in
      try SourceRecord
        .where { $0.id.eq(source) }
        .select { $0.signature }
        .fetchOne(db) ?? nil
    }
  }

  /// Returns every indexed framework's module name across all sources,
  /// sorted case-insensitively.
  ///
  /// - Returns: Every indexed framework's module name across all sources,
  ///   sorted case-insensitively.
  /// - Throws: An error if the underlying database read fails.
  public func allFrameworkNames() async throws -> [String] {
    try await database.read { db in
      try FrameworkRecord
        .order { $0.moduleName.collate(.nocase) }
        .select { $0.moduleName }
        .fetchAll(db)
    }
  }

  /// Returns the platforms that appear in `source`'s index, in canonical
  /// display order.
  ///
  /// - Parameter source: The source whose index is read.
  /// - Returns: The platforms that appear in `source`'s index, in canonical
  ///   display order.
  /// - Throws: An error if the underlying database read fails.
  public func indexedPlatforms(source: Source.ID) async throws
    -> [ApplePlatform]
  {
    let raw = try await database.read { db in
      try AvailabilityRecord
        .distinct()
        .join(SymbolRecord.all) { $0.symbolId.eq($1.id) }
        .join(FrameworkRecord.all) { $1.frameworkId.eq($2.id) }
        .where { availability, _, framework in
          availability.domainKind.eq("platform")
            && framework.sourceId.eq(source)
        }
        .select { availability, _, _ in availability.domainValue }
        .fetchAll(db)
    }
    let present = Set(raw.compactMap(ApplePlatform.init(rawValue:)))
    return ApplePlatform.allCases.filter(present.contains)
  }

  /// Returns every registered source, sorted by display name, including ones
  /// with no frameworks staged yet.
  ///
  /// - Returns: Every registered source, sorted by display name, including
  ///   ones with no frameworks staged yet.
  /// - Throws: An error if the underlying database read fails.
  public func sources() async throws -> [Source] {
    try await database.read { db in
      try SourceRecord
        .order { $0.displayName }
        .select {
          SourceRow.Columns(
            id: $0.id, kind: $0.kind, displayName: $0.displayName
          )
        }
        .fetchAll(db)
        .compactMap { row in
          SourceKind(rawValue: row.kind).map {
            Source(id: row.id, kind: $0, displayName: row.displayName)
          }
        }
    }
  }

  /// Returns every source's index with its recorded signature, symbol count,
  /// and approximate on-disk footprint.
  ///
  /// The footprint prorates the database file size by each source's share of
  /// the symbols, since SQLite does not attribute file bytes to row subsets.
  ///
  /// - Returns: Every source's index, with its recorded signature, symbol
  ///   count, and approximate on-disk footprint.
  /// - Throws: An error if the underlying database read fails.
  public func indexedSources() async throws -> [IndexedSource] {
    try await database.read { db in
      let rows =
        try SourceRecord
          .leftJoin(FrameworkRecord.all) { $0.id.eq($1.sourceId) }
          .leftJoin(SymbolRecord.all) { $1.id.eq($2.frameworkId) }
          .group { source, _, _ in source.id }
          .order { source, _, _ in source.displayName }
          .select { source, _, symbol in
            IndexedSourceRow.Columns(
              id: source.id,
              kind: source.kind,
              displayName: source.displayName,
              signature: source.signature,
              symbolCount: symbol.id.count()
            )
          }
          .fetchAll(db)
      let pageCount = try Int.fetchOne(db, sql: "PRAGMA page_count") ?? 0
      let pageSize = try Int.fetchOne(db, sql: "PRAGMA page_size") ?? 0
      let totalBytes = Int64(pageCount) * Int64(pageSize)
      let totalSymbols = rows.reduce(0) { $0 + $1.symbolCount }
      return rows.compactMap { row in
        guard let kind = SourceKind(rawValue: row.kind) else { return nil }
        let bytes =
          totalSymbols == 0
            ? Int64(0)
            : totalBytes * Int64(row.symbolCount) / Int64(totalSymbols)
        return IndexedSource(
          source: Source(id: row.id, kind: kind, displayName: row.displayName),
          signature: row.signature,
          symbolCount: row.symbolCount,
          estimatedByteCount: bytes
        )
      }
    }
  }

  /// Returns the `major.minor` OS releases in which any API on the given
  /// platform in `source`'s index was introduced, newest first.
  ///
  /// - Parameters:
  ///   - platform: The platform whose releases to return.
  ///   - source: The source whose index is read.
  /// - Returns: The `major.minor` OS releases in which any API on `platform`
  ///   was introduced, newest first.
  /// - Throws: An error if the underlying database read fails.
  public func indexedReleases(
    for platform: ApplePlatform, source: Source.ID
  ) async throws
    -> [SemanticVersion]
  {
    let platformValue = platform.rawValue
    return try await database.read { db in
      try AvailabilityRecord
        .distinct()
        .join(SymbolRecord.all) { $0.symbolId.eq($1.id) }
        .join(FrameworkRecord.all) { $1.frameworkId.eq($2.id) }
        .where { availability, _, framework in
          availability.domainKind.eq("platform")
            && availability.domainValue.eq(platformValue)
            && framework.sourceId.eq(source)
            && availability.major.isNot(nil)
        }
        .order { availability, _, _ in
          (availability.major.desc(), availability.minor.desc())
        }
        .select { availability, _, _ in
          ReleaseRow.Columns(
            major: availability.major.ifnull(0),
            minor: availability.minor.ifnull(0)
          )
        }
        .fetchAll(db)
        .map { SemanticVersion(major: $0.major, minor: $0.minor) }
    }
  }

  /// Returns each platform's `major.minor` OS releases in `source`'s index,
  /// each list newest first.
  ///
  /// The method fetches every platform in one query instead of one query per
  /// platform.
  ///
  /// - Parameter source: The source whose index is read.
  /// - Returns: Each platform's `major.minor` OS releases in `source`'s
  ///   index, each list newest first.
  /// - Throws: An error if the underlying database read fails.
  public func indexedReleasesByPlatform(source: Source.ID) async throws
    -> [ApplePlatform:
      [SemanticVersion]]
  {
    try await database.read { db in
      let sections =
        try AvailabilityRecord
          .distinct()
          .join(SymbolRecord.all) { $0.symbolId.eq($1.id) }
          .join(FrameworkRecord.all) { $1.frameworkId.eq($2.id) }
          .where { availability, _, framework in
            availability.domainKind.eq("platform")
              && framework.sourceId.eq(source)
              && availability.major.isNot(nil)
          }
          .order { availability, _, _ in
            (availability.major.desc(), availability.minor.desc())
          }
          .select { availability, _, _ in
            ReleaseRow.Columns(
              major: availability.major.ifnull(0),
              minor: availability.minor.ifnull(0)
            )
          }
          .fetchAll(
            db, sectionBy: { availability, _, _ in availability.domainValue }
          )
      var result: [ApplePlatform: [SemanticVersion]] = [:]
      for name in sections.sectionNames {
        guard let platform = ApplePlatform(rawValue: name),
              let section = sections[sectionName: name]
        else { continue }
        result[platform] = section.map {
          SemanticVersion(major: $0.major, minor: $0.minor)
        }
      }
      return result
    }
  }

  /// Returns frameworks in `source`'s index containing API new for
  /// `selections`, with a per-framework count of distinct new symbols.
  ///
  /// A symbol new on two selected platforms at the same release counts once,
  /// matching the tree.
  ///
  /// - Parameters:
  ///   - selections: The OS releases that count as new.
  ///   - source: The source whose index is read.
  /// - Returns: The frameworks in `source`'s index containing new API, each
  ///   with its count of distinct new symbols.
  /// - Throws: An error if the underlying database read fails.
  public func frameworksWithNewSymbols(
    for selections: [VersionSelection], source: Source.ID
  )
    async throws
    -> [FrameworkSummary]
  {
    guard !selections.isEmpty else { return [] }
    return try await database.read { db in
      // Each selection runs as its own query instead of building dynamic
      // SQL. The USRs are unioned per framework below.
      var usrsByModule: [String: Set<String>] = [:]
      for selection in selections {
        let platform = selection.platform.rawValue
        let major = selection.version.major
        let minor = selection.version.minor
        let rows =
          try FrameworkRecord
            .join(SymbolRecord.all) { $1.frameworkId.eq($0.id) }
            .join(AvailabilityRecord.all) { $2.symbolId.eq($1.id) }
            .where { framework, _, availability in
              framework.sourceId.eq(source)
                && availability.domainKind.eq("platform")
                && availability.domainValue.eq(platform)
                && availability.major.eq(major)
                && availability.minor.eq(minor)
            }
            .select { framework, symbol, _ in
              FrameworkSymbolRow.Columns(
                moduleName: framework.moduleName, usr: symbol.usr
              )
            }
            .fetchAll(db)
        for row in rows {
          usrsByModule[row.moduleName, default: []].insert(row.usr)
        }
      }
      return
        usrsByModule
          .map {
            FrameworkSummary(moduleName: $0.key, newSymbolCount: $0.value.count)
          }
          .sorted {
            $0.moduleName.localizedCaseInsensitiveCompare($1.moduleName)
              == .orderedAscending
          }
    }
  }

  /// Returns every framework's module name in `source`'s index, sorted for
  /// display.
  ///
  /// - Parameter source: The source whose index is read.
  /// - Returns: Every framework's module name in `source`'s index, sorted
  ///   for display.
  /// - Throws: An error if the underlying database read fails.
  public func frameworkNames(source: Source.ID) async throws -> [String] {
    try await database.read { db in
      try FrameworkRecord
        .where { $0.sourceId.eq(source) }
        .select { $0.moduleName }
        .fetchAll(db)
    }
    .sorted {
      $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
    }
  }

  /// Returns the full `FrameworkIndex` for one framework in `source`'s
  /// index, or `nil` if the module has no indexed symbols there.
  ///
  /// - Parameters:
  ///   - moduleName: The framework's module name.
  ///   - source: The source whose index is read.
  /// - Returns: The framework's full index, or `nil` if it has no indexed
  ///   symbols in `source`'s index.
  /// - Throws: An error if the underlying database read fails.
  public func frameworkIndex(
    forModule moduleName: String, source: Source.ID
  ) async throws
    -> FrameworkIndex?
  {
    try await database.read { db -> FrameworkIndex? in
      let frameworkIds =
        FrameworkRecord
          .where { $0.moduleName.eq(moduleName) && $0.sourceId.eq(source) }
          .select { $0.id }
      let symbolRows =
        try SymbolRecord
          .where { $0.frameworkId.in(frameworkIds) }
          .fetchAll(db)
      guard !symbolRows.isEmpty else { return nil }

      let sections =
        try AvailabilityRecord
          .where {
            $0.symbolId.in(
              SymbolRecord
                .where { $0.frameworkId.in(frameworkIds) }
                .select { $0.id }
            )
          }
          .order { ($0.domainKind, $0.domainValue) }
          .fetchAll(db, sectionBy: \.symbolId)

      var availabilityBySymbol: [Int: [Availability]] = [:]
      for symbolId in sections.sectionNames {
        guard let section = sections[sectionName: symbolId] else { continue }
        availabilityBySymbol[symbolId] = section.compactMap { row in
          guard let domain = Self.domain(
            kind: row.domainKind, value: row.domainValue
          )
          else {
            return nil
          }
          let version = row.major.map {
            SemanticVersion(
              major: $0, minor: row.minor ?? 0, patch: row.patch ?? 0
            )
          }
          return Availability(domain: domain, introduced: version)
        }
      }

      let decoder = JSONDecoder()
      let symbols: [IndexedSymbol] = symbolRows.map { row in
        let pathComponents =
          (try? decoder.decode(
            [String].self, from: Data(row.pathComponents.utf8)
          )) ?? []
        return IndexedSymbol(
          usr: row.usr,
          title: row.title,
          kind: SymbolKind(rawValue: row.kind) ?? .other,
          pathComponents: pathComponents,
          parentUSR: row.parentUSR,
          availability: availabilityBySymbol[row.id] ?? [],
          isDeprecated: row.isDeprecated,
          summary: row.summary
        )
      }
      return FrameworkIndex(moduleName: moduleName, symbols: symbols)
    }
  }

  /// Returns full-text search hits for symbol names and titles in `source`'s
  /// index, optionally restricted to symbols new for `selections` and to the
  /// given `kinds`.
  ///
  /// Tokens are matched as prefixes.
  ///
  /// - Parameters:
  ///   - query: The search text to match.
  ///   - source: The source whose index is read.
  ///   - selections: The OS releases that count as new, or `nil` to include
  ///     every release.
  ///   - kinds: The symbol kinds to include, or `nil` to include every kind.
  ///   - limit: The maximum number of hits to return.
  /// - Returns: The full-text search hits for `query` in `source`'s index.
  /// - Throws: An error if the underlying database read fails.
  public func search(
    query: String,
    source: Source.ID,
    selections: [VersionSelection]? = nil,
    kinds: Set<SymbolKind>? = nil,
    limit: Int = IndexStore.defaultSearchLimit
  ) async throws -> [SearchHit] {
    guard let match = Self.ftsMatchExpression(for: query) else { return [] }
    let showAllKinds = (kinds?.isEmpty ?? true) ? 1 : 0
    let kindsJSON = Self.jsonArray(kinds?.map(\.rawValue))

    let rows = try await database.read { db -> [SearchRow] in
      guard let selections, !selections.isEmpty else {
        return try #sql(
          """
          SELECT s.usr, s.title, s.name, s.kind, s.pathComponents, f.moduleName AS moduleName, bm25(symbol_fts) AS rank
          FROM symbol_fts
          JOIN symbol s ON s.id = symbol_fts.symbolId
          JOIN framework f ON s.frameworkId = f.id
          WHERE symbol_fts MATCH \(bind: match)
            AND f.sourceId = \(bind: source)
            AND (\(
              bind: showAllKinds
            ) = 1 OR s.kind IN (SELECT value FROM json_each(\(bind: kindsJSON))))
          ORDER BY rank, s.usr
          LIMIT \(bind: limit)
          """,
          as: SearchRow.self
        ).fetchAll(db)
      }
      var best: [String: SearchRow] = [:]
      for selection in selections {
        let platform = selection.platform.rawValue
        let major = selection.version.major
        let minor = selection.version.minor
        let matched = try #sql(
          """
          SELECT s.usr, s.title, s.name, s.kind, s.pathComponents, f.moduleName AS moduleName, bm25(symbol_fts) AS rank
          FROM symbol_fts
          JOIN symbol s ON s.id = symbol_fts.symbolId
          JOIN framework f ON s.frameworkId = f.id
          WHERE symbol_fts MATCH \(bind: match)
            AND f.sourceId = \(bind: source)
            AND (\(
              bind: showAllKinds
            ) = 1 OR s.kind IN (SELECT value FROM json_each(\(bind: kindsJSON))))
            AND EXISTS (
              SELECT 1 FROM availability i
              WHERE i.symbolId = s.id AND i.domainKind = 'platform' AND i.domainValue = \(
                bind: platform
              ) AND i.major = \(bind: major) AND i.minor = \(bind: minor)
            )
          ORDER BY rank
          """,
          as: SearchRow.self
        ).fetchAll(db)
        for row in matched
          where (best[row.usr]?.rank ?? .greatestFiniteMagnitude) > row.rank
        {
          best[row.usr] = row
        }
      }
      return Array(best.values).sorted {
        ($0.rank, $0.usr) < ($1.rank, $1.usr)
      }
    }

    let decoder = JSONDecoder()
    var seen: Set<String> = []
    return rows.filter { seen.insert($0.usr).inserted }.prefix(limit).map {
      row in
      let pathComponents =
        (try? decoder.decode(
          [String].self, from: Data(row.pathComponents.utf8)
        ))
        ?? []
      return SearchHit(
        usr: row.usr,
        title: row.title,
        name: row.name,
        kind: SymbolKind(rawValue: row.kind) ?? .other,
        moduleName: row.moduleName,
        pathComponents: pathComponents
      )
    }
  }

  // MARK: - Private

  private static func jsonArray(_ values: [String]?) -> String {
    guard let values, !values.isEmpty,
          let data = try? JSONEncoder().encode(values)
    else {
      return "[]"
    }
    return String(decoding: data, as: UTF8.self)
  }

  static func domain(kind: String, value: String) -> AvailabilityDomain? {
    switch kind {
    case "platform":
      ApplePlatform(rawValue: value).map(AvailabilityDomain.platform)
    case "package": .package(value)
    default: nil
    }
  }
}
