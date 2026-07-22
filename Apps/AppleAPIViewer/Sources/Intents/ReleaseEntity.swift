import AppIntents
import CoreModel
import SymbolGraphIndex

struct ReleaseEntity: AppEntity {
  static let typeDisplayRepresentation = TypeDisplayRepresentation(
    name: "OS Release"
  )
  static let defaultQuery = ReleaseEntityQuery()

  let platform: ApplePlatform
  let version: SemanticVersion

  var id: String { "\(platform.rawValue):\(version)" }

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: "\(platform.displayName) \(version.description)"
    )
  }

  var selection: VersionSelection {
    VersionSelection(platform: platform, version: version)
  }
}

struct ReleaseEntityQuery: EntityQuery {
  @Dependency private var services: IntentServices

  private func allReleases() async throws -> [ReleaseEntity] {
    guard let source = await services.resolveSource() else { return [] }
    let releases = try await services.query.indexedReleasesByPlatform(
      source: source
    )
    return ApplePlatform.allCases.flatMap { platform in
      (releases[platform] ?? [])
        .filter { !$0.isUnversioned }
        .map { ReleaseEntity(platform: platform, version: $0) }
    }
  }

  func entities(for identifiers: [String]) async throws -> [ReleaseEntity] {
    let releases = try await allReleases()
    return identifiers.compactMap { identifier in
      releases.first { $0.id == identifier }
    }
  }

  func suggestedEntities() async throws -> [ReleaseEntity] {
    try await allReleases()
  }
}
