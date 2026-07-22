import CoreModel
import SymbolGraphIndex
import Testing
@testable import AppleAPIViewerCore

@Suite("New API export", .tags(.export))
struct NewAPIExportTests {
  static let selections = [
    VersionSelection(platform: .iOS, version: SemanticVersion(major: 26)),
    VersionSelection(platform: .macOS, version: SemanticVersion(major: 26)),
  ]

  @Test("Markdown links matches and keeps parents plain")
  func markdownLinksMatchesAndKeepsParentsPlain() {
    let markdown = NewAPIExport.markdown(
      module: "PencilKit", selections: Self.selections, tree: Self.tree()
    )

    #expect(markdown.hasPrefix("# What's new in PencilKit"))
    #expect(markdown.contains("New in iOS 26.0 and macOS 26.0"))
    #expect(markdown.contains("- PKStroke (Struct)"))
    #expect(
      markdown.contains(
        "[PKStroke.RenderState.grainOffset](https://developer.apple.com/documentation/pencilkit/pkstroke/renderstate/grainoffset)"
      )
    )
    #expect(markdown.contains("new in iOS 26.0"))
  }

  @Test("Markdown escapes markup characters in symbol titles")
  func markdownEscapesMarkupCharactersInSymbolTitles() {
    let initializer = SymbolTreeNode(
      symbol: IndexedSymbol(
        usr: "s:init", title: "init(_:_:)", kind: .initializer,
        pathComponents: ["PKStroke", "init(_:_:)"], parentUSR: "s:PKStroke",
        introduced: [.iOS: SemanticVersion(major: 26)], isDeprecated: false
      ),
      isMatch: true, children: []
    )
    let parent = SymbolTreeNode(
      symbol: IndexedSymbol(
        usr: "s:op", title: "==(_:_:)", kind: .operator,
        pathComponents: ["==(_:_:)"], parentUSR: nil,
        introduced: [:], isDeprecated: false
      ),
      isMatch: false, children: [initializer]
    )
    let markdown = NewAPIExport.markdown(
      module: "PencilKit", selections: [], tree: [parent]
    )
    #expect(markdown.contains("[init(\\_:\\_:)]"))
    #expect(markdown.contains("- ==(\\_:\\_:) (Operator)"))
  }

  @Test("Model lines flatten the tree depth first")
  func modelLinesFlattenTheTreeDepthFirst() {
    let lines = NewAPIExport.modelLines(tree: Self.tree())
      .split(separator: "\n")

    #expect(lines.count == 3)
    #expect(lines.first?.hasSuffix("PKStroke") == true)
    #expect(lines[1].hasSuffix("PKStroke.RenderState.grainOffset"))
    #expect(lines.last?.hasPrefix("Enum PKToolPickerVisibility") == true)
  }

  @Test("Model line chunks split per top level subtree")
  func modelLineChunksSplitPerTopLevelSubtree() {
    let chunks = NewAPIExport.modelLineChunks(tree: Self.tree())

    #expect(chunks.count == 2)
    #expect(chunks[0].contains("grainOffset"))
    #expect(!chunks[1].contains("grainOffset"))
  }

  @Test("Match count excludes context only parents")
  func matchCountExcludesContextOnlyParents() {
    #expect(NewAPIExport.matchCount(in: Self.tree()) == 2)
  }

  @Test("Plain digest names every new symbol with its kind")
  func plainDigestNamesEveryNewSymbolWithItsKind() {
    let digest = NewAPIExport.plainDigest(
      module: "PencilKit", tree: Self.tree()
    )

    #expect(
      digest
        == "PencilKit adds the PKStroke.RenderState.grainOffset instance property and the PKToolPickerVisibility enum."
    )
    #expect(NewAPIExport.plainDigest(module: "PencilKit", tree: []).isEmpty)
  }

  @Test("Model lines use readable kind labels")
  func modelLinesUseReadableKindLabels() {
    let lines = NewAPIExport.modelLines(tree: Self.tree())

    #expect(lines.contains("Instance property"))
    #expect(!lines.contains("enumCase"))
  }

  @Test("Model lines attach first sentence abstracts to types only")
  func modelLinesAttachFirstSentenceAbstractsToTypesOnly() {
    let lines = NewAPIExport.modelLines(tree: Self.tree())

    #expect(
      lines.contains(
        "Enum PKToolPickerVisibility: The visibility states of a tool picker."
      )
    )
    #expect(!lines.contains("It has cases"))
    #expect(!lines.contains("The grain offset of a stroke."))
  }

  @Test("Releases label skips empty selections")
  func releasesLabelSkipsEmptySelections() {
    #expect(NewAPIExport.releasesLabel(for: []).isEmpty)
    #expect(
      NewAPIExport.releasesLabel(for: [Self.selections[0]])
        == "New in iOS 26.0"
    )
  }

  // MARK: - Helpers

  static func tree() -> [SymbolTreeNode] {
    let member = SymbolTreeNode(
      symbol: IndexedSymbol(
        usr: "s:grainOffset", title: "PKStroke.RenderState.grainOffset",
        kind: .property,
        pathComponents: ["PKStroke", "RenderState", "grainOffset"],
        parentUSR: "s:RenderState",
        introduced: [.iOS: SemanticVersion(major: 26)], isDeprecated: false,
        summary: "The grain offset of a stroke."
      ),
      isMatch: true, children: []
    )
    let parent = SymbolTreeNode(
      symbol: IndexedSymbol(
        usr: "s:PKStroke", title: "PKStroke", kind: .structure,
        pathComponents: ["PKStroke"], parentUSR: nil,
        introduced: [:], isDeprecated: false
      ),
      isMatch: false, children: [member]
    )
    let standalone = SymbolTreeNode(
      symbol: IndexedSymbol(
        usr: "s:Visibility", title: "PKToolPickerVisibility",
        kind: .enumeration,
        pathComponents: ["PKToolPickerVisibility"], parentUSR: nil,
        introduced: [.iOS: SemanticVersion(major: 26)], isDeprecated: false,
        summary: "The visibility states of a tool picker. It has cases."
      ),
      isMatch: true, children: []
    )
    return [parent, standalone]
  }
}
