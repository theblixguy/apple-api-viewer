import CoreModel
import SQLiteData
import SymbolGraphIndex

extension Collation {
  static let nocase = Collation(rawValue: "NOCASE")
}

// MARK: - Table records

@Table("source")
struct SourceRecord {
  let id: String
  let kind: String
  let displayName: String
  let signature: String?
}

@Table("framework")
struct FrameworkRecord {
  let id: Int
  let moduleName: String
  let sourceId: String
}

@Table("symbol")
struct SymbolRecord {
  let id: Int
  let usr: String
  let frameworkId: Int
  let title: String
  let name: String
  let kind: String
  let pathComponents: String
  let parentUSR: String?
  let isDeprecated: Bool
  let summary: String?
}

@Table("availability")
struct AvailabilityRecord {
  let symbolId: Int
  let domainKind: String
  let domainValue: String
  let major: Int?
  let minor: Int?
  let patch: Int?
}

@Table("source_staging")
struct SourceStagingRecord {
  let id: String
  let kind: String
  let displayName: String
}

@Table("framework_staging")
struct FrameworkStagingRecord {
  let id: Int
  let moduleName: String
  let sourceId: String
}

@Table("symbol_staging")
struct SymbolStagingRecord {
  let frameworkId: Int
  let usr: String
  let title: String
  let name: String
  let kind: String
  let pathComponents: String
  let parentUSR: String?
  let isDeprecated: Bool
  let summary: String?
  let searchText: String
}

@Table("symbol_fts")
struct SymbolFTSRecord {
  let symbolId: Int
  let searchText: String
}

@Table("availability_staging")
struct AvailabilityStagingRecord {
  let frameworkId: Int
  let symbolUSR: String
  let domainKind: String
  let domainValue: String
  let major: Int?
  let minor: Int?
  let patch: Int?
}

// MARK: - Selection rows

@Selection struct ReleaseRow {
  let major: Int
  let minor: Int
}

@Selection struct FrameworkSymbolRow {
  let moduleName: String
  let usr: String
}

@Selection struct SourceSymbolRow {
  let id: Int
  let usr: String
  let title: String
  let kind: String
  let pathComponents: String
  let parentUSR: String?
  let isDeprecated: Bool
  let moduleName: String
}

@Selection struct SourceRow {
  let id: String
  let kind: String
  let displayName: String
}

@Selection struct IndexedSourceRow {
  let id: String
  let kind: String
  let displayName: String
  let signature: String?
  let symbolCount: Int
}

@Selection struct SearchRow {
  let usr: String
  let title: String
  let name: String
  let kind: String
  let pathComponents: String
  let moduleName: String
  let rank: Double
}
