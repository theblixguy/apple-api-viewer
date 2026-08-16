import CoreModel
import SymbolGraphIndex
import Testing

@Suite("Framework diff", .tags(.diffing))
struct FrameworkDiffTests {
  // MARK: - Added and removed

  @Test("Symbols split into added and removed by USR")
  func splitsAddedAndRemovedByUSR() {
    let old = Self.framework(
      Self.symbol(usr: "s:Old", path: ["OldType"], kind: .structure),
      Self.symbol(usr: "s:Kept", path: ["KeptType"], kind: .structure)
    )
    let new = Self.framework(
      Self.symbol(usr: "s:Kept", path: ["KeptType"], kind: .structure),
      Self.symbol(usr: "s:New", path: ["NewType"], kind: .structure)
    )

    let diff = FrameworkDiff(from: old, to: new)

    #expect(diff.added.map(\.usr) == ["s:New"])
    #expect(diff.removed.map(\.usr) == ["s:Old"])
    #expect(diff.changed.isEmpty)
    #expect(!diff.isEmpty)
  }

  @Test("Identical snapshots produce an empty diff")
  func identicalSnapshotsProduceEmptyDiff() {
    let index = Self.framework(
      Self.symbol(usr: "s:A", path: ["A"], kind: .structure)
    )

    let diff = FrameworkDiff(from: index, to: index)

    #expect(diff.isEmpty)
    #expect(diff.moduleName == "Fixture")
  }

  // MARK: - Signature pairing

  @Test("A removed and added pair at one path counts as a signature change")
  func pairsSamePathAsSignatureChange() throws {
    let old = Self.framework(
      Self.symbol(usr: "s:f-v1", path: ["Type", "f(_:)"], kind: .method)
    )
    let new = Self.framework(
      Self.symbol(usr: "s:f-v2", path: ["Type", "f(_:)"], kind: .method)
    )

    let diff = FrameworkDiff(from: old, to: new)

    #expect(diff.added.isEmpty)
    #expect(diff.removed.isEmpty)
    let change = try #require(diff.changed.first)
    #expect(change.old.usr == "s:f-v1")
    #expect(change.new.usr == "s:f-v2")
    #expect(change.reasons == [.signature])
  }

  @Test("A leftover overload at a paired path stays added")
  func leavesUnpairedOverloadAsAdded() {
    let old = Self.framework(
      Self.symbol(usr: "s:f-v1", path: ["Type", "f(_:)"], kind: .method)
    )
    let new = Self.framework(
      Self.symbol(usr: "s:f-v2", path: ["Type", "f(_:)"], kind: .method),
      Self.symbol(usr: "s:f-v3", path: ["Type", "f(_:)"], kind: .method)
    )

    let diff = FrameworkDiff(from: old, to: new)

    #expect(diff.changed.map(\.old.usr) == ["s:f-v1"])
    #expect(diff.changed.map(\.new.usr) == ["s:f-v2"])
    #expect(diff.added.map(\.usr) == ["s:f-v3"])
    #expect(diff.removed.isEmpty)
  }

  @Test("Symbols at one path with different kinds do not pair")
  func doesNotPairAcrossKinds() {
    let old = Self.framework(
      Self.symbol(usr: "s:x-var", path: ["x"], kind: .property)
    )
    let new = Self.framework(
      Self.symbol(usr: "s:x-func", path: ["x"], kind: .function)
    )

    let diff = FrameworkDiff(from: old, to: new)

    #expect(diff.changed.isEmpty)
    #expect(diff.added.map(\.usr) == ["s:x-func"])
    #expect(diff.removed.map(\.usr) == ["s:x-var"])
  }

  @Test("A paired change also records its other differences")
  func pairedChangeRecordsOtherDifferences() {
    let old = Self.framework(
      Self.symbol(
        usr: "s:f-v1", path: ["Type", "f(_:)"], kind: .method,
        isDeprecated: false
      )
    )
    let new = Self.framework(
      Self.symbol(
        usr: "s:f-v2", path: ["Type", "f(_:)"], kind: .method,
        isDeprecated: true
      )
    )

    let diff = FrameworkDiff(from: old, to: new)

    #expect(diff.changed.first?.reasons == [.signature, .deprecation])
  }

  // MARK: - Same-USR changes

  @Test("A deprecation flip counts as a change")
  func deprecationFlipCountsAsChange() {
    let old = Self.framework(
      Self.symbol(usr: "s:A", path: ["A"], kind: .structure)
    )
    let new = Self.framework(
      Self.symbol(usr: "s:A", path: ["A"], kind: .structure, isDeprecated: true)
    )

    let diff = FrameworkDiff(from: old, to: new)

    #expect(diff.changed.map(\.id) == ["s:A"])
    #expect(diff.changed.first?.reasons == [.deprecation])
    #expect(diff.added.isEmpty)
    #expect(diff.removed.isEmpty)
  }

  @Test("An availability edit counts as a change")
  func availabilityEditCountsAsChange() {
    let old = Self.framework(
      Self.symbol(
        usr: "s:A", path: ["A"], kind: .structure,
        introduced: [.iOS: SemanticVersion(major: 26)]
      )
    )
    let new = Self.framework(
      Self.symbol(
        usr: "s:A", path: ["A"], kind: .structure,
        introduced: [
          .iOS: SemanticVersion(major: 26),
          .macOS: SemanticVersion(major: 27),
        ]
      )
    )

    let diff = FrameworkDiff(from: old, to: new)

    #expect(diff.changed.first?.reasons == [.availability])
  }

  // MARK: - Summary

  @Test("The summary carries the diff's counts")
  func summaryCarriesCounts() {
    let old = Self.framework(
      Self.symbol(usr: "s:Old", path: ["OldType"], kind: .structure),
      Self.symbol(usr: "s:Kept", path: ["KeptType"], kind: .structure)
    )
    let new = Self.framework(
      Self.symbol(
        usr: "s:Kept", path: ["KeptType"], kind: .structure, isDeprecated: true
      ),
      Self.symbol(usr: "s:New", path: ["NewType"], kind: .structure)
    )

    let summary = FrameworkDiffSummary(FrameworkDiff(from: old, to: new))

    #expect(summary.moduleName == "Fixture")
    #expect(summary.addedCount == 1)
    #expect(summary.removedCount == 1)
    #expect(summary.changedCount == 1)
    #expect(!summary.isEmpty)
  }

  // MARK: - Fixtures

  private static func framework(_ symbols: IndexedSymbol...) -> FrameworkIndex {
    FrameworkIndex(moduleName: "Fixture", symbols: symbols)
  }

  private static func symbol(
    usr: String,
    path: [String],
    kind: SymbolKind,
    isDeprecated: Bool = false,
    introduced: [ApplePlatform: SemanticVersion] = [
      .iOS: SemanticVersion(major: 26),
    ]
  ) -> IndexedSymbol {
    IndexedSymbol(
      usr: usr,
      title: path.joined(separator: "."),
      kind: kind,
      pathComponents: path,
      parentUSR: nil,
      introduced: introduced,
      isDeprecated: isDeprecated
    )
  }
}
