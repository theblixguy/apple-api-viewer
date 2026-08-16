import CoreModel
import Foundation
import SQLiteData
import SymbolGraphIndex

extension IndexStore {
  /// Returns the diff of one framework between two sources' indexes.
  ///
  /// A module that one source does not index diffs against an empty
  /// snapshot, so all of its symbols count as added or removed.
  ///
  /// - Parameters:
  ///   - moduleName: The framework's module name.
  ///   - oldSource: The source whose index is the old snapshot.
  ///   - newSource: The source whose index is the new snapshot.
  /// - Returns: The framework's diff between the two sources' indexes.
  /// - Throws: An error if the underlying database read fails.
  public func frameworkDiff(
    forModule moduleName: String,
    from oldSource: Source.ID,
    to newSource: Source.ID
  ) async throws -> FrameworkDiff {
    let empty = FrameworkIndex(moduleName: moduleName, symbols: [])
    let old =
      try await frameworkIndex(forModule: moduleName, source: oldSource)
        ?? empty
    let new =
      try await frameworkIndex(forModule: moduleName, source: newSource)
        ?? empty
    return FrameworkDiff(from: old, to: new)
  }

  /// Returns each framework's diff counts between two sources' indexes,
  /// sorted by module name and without frameworks whose API is the same in
  /// both.
  ///
  /// - Parameters:
  ///   - oldSource: The source whose index is the old snapshot.
  ///   - newSource: The source whose index is the new snapshot.
  /// - Returns: Each changed framework's diff counts between the two
  ///   sources' indexes.
  /// - Throws: An error if the underlying database read fails.
  public func frameworkDiffSummaries(
    from oldSource: Source.ID, to newSource: Source.ID
  ) async throws -> [FrameworkDiffSummary] {
    let old = try await snapshots(source: oldSource)
    let new = try await snapshots(source: newSource)
    return Set(old.keys)
      .union(new.keys)
      .map { moduleName in
        let empty = FrameworkIndex(moduleName: moduleName, symbols: [])
        return FrameworkDiffSummary(
          FrameworkDiff(
            from: old[moduleName] ?? empty, to: new[moduleName] ?? empty
          )
        )
      }
      .filter { !$0.isEmpty }
      .sorted {
        $0.moduleName.localizedCaseInsensitiveCompare($1.moduleName)
          == .orderedAscending
      }
  }

  // MARK: - Private

  // The read skips the summary column. Summary text dominates the row size,
  // and the diff counts do not need it.
  private func snapshots(source: Source.ID) async throws
    -> [String: FrameworkIndex]
  {
    try await database.read { db in
      let frameworkIds =
        FrameworkRecord
          .where { $0.sourceId.eq(source) }
          .select { $0.id }
      let symbolRows =
        try SymbolRecord
          .join(FrameworkRecord.all) { $0.frameworkId.eq($1.id) }
          .where { _, framework in framework.sourceId.eq(source) }
          .select { symbol, framework in
            SourceSymbolRow.Columns(
              id: symbol.id,
              usr: symbol.usr,
              title: symbol.title,
              kind: symbol.kind,
              pathComponents: symbol.pathComponents,
              parentUSR: symbol.parentUSR,
              isDeprecated: symbol.isDeprecated,
              moduleName: framework.moduleName
            )
          }
          .fetchAll(db)
      guard !symbolRows.isEmpty else { return [:] }

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
      var symbolsByModule: [String: [IndexedSymbol]] = [:]
      for row in symbolRows {
        let pathComponents =
          (try? decoder.decode(
            [String].self, from: Data(row.pathComponents.utf8)
          )) ?? []
        let symbol = IndexedSymbol(
          usr: row.usr,
          title: row.title,
          kind: SymbolKind(rawValue: row.kind) ?? .other,
          pathComponents: pathComponents,
          parentUSR: row.parentUSR,
          availability: availabilityBySymbol[row.id] ?? [],
          isDeprecated: row.isDeprecated
        )
        symbolsByModule[row.moduleName, default: []].append(symbol)
      }
      return symbolsByModule.reduce(into: [:]) { result, entry in
        result[entry.key] = FrameworkIndex(
          moduleName: entry.key, symbols: entry.value
        )
      }
    }
  }
}
