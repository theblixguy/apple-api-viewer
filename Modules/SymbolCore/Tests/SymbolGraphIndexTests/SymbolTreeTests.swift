import CoreModel
import Foundation
import Testing
@testable import SymbolGraphIndex

@Suite("Symbol tree", .tags(.symbolTree))
struct SymbolTreeTests {
  @Test("New member nests under its preexisting type")
  func nestsNewMemberUnderPreexistingType() throws {
    let tree = try Self.loadIndex().newSymbolTree(
      for: [
        VersionSelection(
          platform: .iOS, version: SemanticVersion(major: 27, minor: 0)
        ),
      ]
    )

    let pkStroke = try #require(tree.first { $0.symbol.title == "PKStroke" })
    #expect(!pkStroke.isMatch)
    #expect(pkStroke.containsMatch)

    let renderState = try #require(
      pkStroke.children.first { $0.symbol.title == "PKStroke.RenderState" }
    )
    #expect(renderState.isMatch)
    #expect(renderState.children.contains { $0.symbol.name == "grainOffset" })
  }

  @Test("An explicit USR match set builds the tree with ancestors")
  func buildsTreeFromExplicitUSRMatchSet() throws {
    let tree = try Self.loadIndex().tree(
      matchingUSRs: [
        "s:9PencilKit8PKStrokeV11RenderStateV11grainOffsetSo7CGPointVSgvp",
      ]
    )

    let pkStroke = try #require(tree.first { $0.symbol.title == "PKStroke" })
    #expect(!pkStroke.isMatch)
    let renderState = try #require(
      pkStroke.children.first { $0.symbol.title == "PKStroke.RenderState" }
    )
    #expect(!renderState.isMatch)
    let grainOffset = try #require(
      renderState.children.first { $0.symbol.name == "grainOffset" }
    )
    #expect(grainOffset.isMatch)

    #expect(try Self.loadIndex().tree(matchingUSRs: ["s:unknown"]).isEmpty)
    #expect(try Self.loadIndex().tree(matchingUSRs: []).isEmpty)
  }

  @Test("Tree is empty when nothing matches")
  func returnsEmptyTreeWhenNothingMatches() throws {
    let tree = try Self.loadIndex().newSymbolTree(
      for: [
        VersionSelection(
          platform: .tvOS, version: SemanticVersion(major: 99, minor: 0)
        ),
      ]
    )
    #expect(tree.isEmpty)
  }

  @Test("Symbol with a foreign parent is placed at the root")
  func placesSymbolWithForeignParentAtRoot() {
    let selections = [
      VersionSelection(platform: .iOS, version: SemanticVersion(major: 27)),
    ]
    let index = FrameworkIndex(
      moduleName: "Demo",
      symbols: [
        IndexedSymbol(
          usr: "s:Demo.helper", title: "UIView.demoHelper()", kind: .method,
          pathComponents: ["UIView", "demoHelper()"],
          parentUSR: "c:objc(cs)UIView",
          introduced: [.iOS: SemanticVersion(major: 27)], isDeprecated: false
        ),
      ]
    )

    let tree = index.newSymbolTree(for: selections)
    let root = tree.first { $0.symbol.usr == "s:Demo.helper" }
    #expect(root?.isMatch == true)
    #expect(root?.children.isEmpty == true)
  }

  @Test("Tree filters symbols by kind")
  func filtersTreeByKind() {
    let selections = [
      VersionSelection(platform: .iOS, version: SemanticVersion(major: 27)),
    ]
    let index = FrameworkIndex(
      moduleName: "Demo",
      symbols: [
        IndexedSymbol(
          usr: "s:Foo", title: "Foo", kind: .structure,
          pathComponents: ["Foo"], parentUSR: nil,
          introduced: [.iOS: SemanticVersion(major: 27)], isDeprecated: false
        ),
        IndexedSymbol(
          usr: "s:Foo.bar", title: "Foo.bar()", kind: .method,
          pathComponents: ["Foo", "bar()"], parentUSR: "s:Foo",
          introduced: [.iOS: SemanticVersion(major: 27)], isDeprecated: false
        ),
      ]
    )

    let methods = index.newSymbolTree(for: selections, kinds: [.method])
    #expect(methods.first?.symbol.title == "Foo")
    #expect(methods.first?.isMatch == false)
    #expect(methods.first?.children.first?.symbol.title == "Foo.bar()")
    #expect(methods.first?.children.first?.isMatch == true)

    let structures = index.newSymbolTree(for: selections, kinds: [.structure])
    #expect(structures.first?.symbol.title == "Foo")
    #expect(structures.first?.isMatch == true)
    #expect(structures.first?.children.isEmpty == true)
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
