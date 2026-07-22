import AppIntents
import CoreModel
import SymbolGraphIndex

struct FrameworkEntity: AppEntity {
  static let typeDisplayRepresentation = TypeDisplayRepresentation(
    name: "Framework"
  )
  static let defaultQuery = FrameworkEntityQuery()

  var id: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(id)")
  }
}

struct FrameworkEntityQuery: EntityStringQuery {
  @Dependency private var services: IntentServices

  private func allNames() async throws -> [String] {
    guard let source = await services.resolveSource() else { return [] }
    return try await services.query.frameworkNames(source: source)
  }

  func entities(for identifiers: [String]) async throws -> [FrameworkEntity] {
    let names = try await allNames()
    return identifiers.compactMap { identifier in
      names.first { $0.caseInsensitiveCompare(identifier) == .orderedSame }
        .map(FrameworkEntity.init(id:))
    }
  }

  func entities(matching string: String) async throws -> [FrameworkEntity] {
    try await allNames()
      .filter { $0.localizedCaseInsensitiveContains(string) }
      .map(FrameworkEntity.init(id:))
  }

  func suggestedEntities() async throws -> [FrameworkEntity] {
    try await allNames().map(FrameworkEntity.init(id:))
  }
}
