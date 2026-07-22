import CoreModel
import Foundation
import Testing
@testable import SymbolGraphIndex

@Suite("Symbol graph parser", .tags(.parsing))
struct SymbolGraphParserTests {
  @Test("Module name is parsed from the symbol graph")
  func parsesModuleName() throws {
    #expect(try Self.loadIndex().moduleName == "PencilKit")
  }

  @Test("Synthesized symbols are excluded")
  func excludesSynthesizedSymbols() throws {
    let index = try Self.loadIndex()
    #expect(index.symbols.allSatisfy { !$0.usr.contains("::SYNTHESIZED::") })
    #expect(!index.symbols.contains { $0.name == "synthesizedFlag" })
  }

  @Test("Introduced versions are read as absolute per platform")
  func readsAbsoluteIntroducedVersionsPerPlatform() throws {
    let index = try Self.loadIndex()
    let renderState = try #require(
      index.symbols.first { $0.title == "PKStroke.RenderState" }
    )
    #expect(renderState.kind == .structure)
    #expect(
      renderState.introduced[.iOS] == SemanticVersion(major: 27, minor: 0)
    )
    #expect(
      renderState.introduced[.macOS] == SemanticVersion(major: 27, minor: 0)
    )
    #expect(
      renderState.introduced[.visionOS] == SemanticVersion(major: 27, minor: 0)
    )
  }

  @Test("Kinds are mapped from language-prefixed identifiers")
  func mapsKindsFromLanguagePrefixedIdentifiers() throws {
    let index = try Self.loadIndex()
    #expect(index.symbols.contains { $0.kind == .enumCase })
    #expect(index.symbols.contains { $0.kind == .enumeration })
    #expect(index.symbols.contains { $0.kind == .initializer })
    #expect(index.symbols.contains { $0.kind == .property })
  }

  @Test("Symbols are filtered by introduced release")
  func filtersByIntroducedRelease() throws {
    let index = try Self.loadIndex()
    let selection = VersionSelection(
      platform: .iOS, version: SemanticVersion(major: 27, minor: 0)
    )
    let new27 = index.newSymbols(for: [selection])

    #expect(new27.contains { $0.title == "PKStroke.RenderState" })
    #expect(new27.allSatisfy { $0.wasIntroduced(in: selection) })
    #expect(!new27.contains { $0.title == "PKStroke" })
  }

  @Test("Absolute versioning finds older releases from the newer SDK")
  func absoluteVersioningFindsOlderReleasesFromTheNewerSDK() throws {
    let index = try Self.loadIndex()
    let new26 = index.newSymbols(for: [
      VersionSelection(
        platform: .iOS, version: SemanticVersion(major: 26, minor: 0)
      ),
    ])
    #expect(!new26.isEmpty)
    #expect(new26.allSatisfy { $0.introduced[.iOS]?.major == 26 })
  }

  @Test("Members are linked to their parent type")
  func linksMembersToTheirParentType() throws {
    let index = try Self.loadIndex()
    let renderState = try #require(
      index.symbols.first { $0.title == "PKStroke.RenderState" }
    )
    let pkStroke = try #require(index.symbols.first { $0.title == "PKStroke" })
    #expect(renderState.parentUSR == pkStroke.usr)
  }

  // MARK: - Helpers

  static func loadIndex() throws -> FrameworkIndex {
    let url = try #require(
      Bundle.module.url(
        forResource: "PencilKitSlice.symbols", withExtension: "json",
        subdirectory: "Fixtures"
      )
    )
    return try SymbolGraphParser.parse(Data(contentsOf: url))
  }
}
