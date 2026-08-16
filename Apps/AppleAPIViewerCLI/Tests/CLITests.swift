import ArgumentParser
import CoreModel
import Foundation
import IndexOrchestration
import IndexStore
import SymbolGraphIndex
import Testing

@Suite("CLI parsing and output", .tags(.cli))
struct CLITests {
  // MARK: - Filters

  @Test("Release filters parse case insensitively")
  func releaseFilterParsesCaseInsensitively() {
    let filter = ReleaseFilter(argument: "ios:26.0")
    #expect(filter?.selection.platform == .iOS)
    #expect(filter?.selection.version == SemanticVersion(major: 26))
    #expect(ReleaseFilter(argument: "IOS:26")?.selection.platform == .iOS)
    #expect(
      ReleaseFilter(argument: "ios:16.4.1")?.selection.version
        == SemanticVersion(major: 16, minor: 4, patch: 1)
    )
  }

  @Test(
    "Release filter rejects malformed input",
    arguments: ["nope:1.0", "ios", "ios:x", "ios:26.x", "ios:26.0.1.2"]
  )
  func releaseFilterRejectsBadInput(_ input: String) {
    #expect(ReleaseFilter(argument: input) == nil)
  }

  @Test("Kind filter parses from a raw value")
  func kindFilterParsesRawValue() {
    #expect(
      KindFilter(argument: SymbolKind.structure.rawValue)?.kind == .structure
    )
    #expect(KindFilter(argument: "notakind") == nil)
  }

  // MARK: - JSON output

  @Test("JSON lines are compact with sorted keys")
  func jsonLineIsCompactAndKeySorted() {
    let json = JSONLine.string(
      FrameworkOutput(module: "PencilKit", newSymbolCount: 3)
    )
    #expect(json == #"{"module":"PencilKit","newSymbolCount":3}"#)
  }

  // MARK: - DTO mapping

  @Test("Search hit output maps fields from a symbol")
  func searchHitOutputMapsFields() {
    let hit = SearchHit(
      usr: "s:1", title: "A.b", name: "b", kind: .property, moduleName: "A",
      pathComponents: ["A", "b"]
    )
    let output = SearchHitOutput(hit)
    #expect(output.kind == SymbolKind.property.rawValue)
    #expect(output.module == "A")
    #expect(output.path == ["A", "b"])
  }

  @Test("Availability output splits platform and package domains")
  func availabilityOutputSplitsPlatformAndPackage() {
    let platform = AvailabilityOutput(
      Availability(
        domain: .platform(.iOS), introduced: SemanticVersion(major: 26)
      )
    )
    #expect(platform.platform == "iOS")
    #expect(platform.package == nil)
    #expect(platform.introduced == "26.0")

    let package = AvailabilityOutput(
      Availability(domain: .package("swift-collections"), introduced: nil)
    )
    #expect(package.package == "swift-collections")
    #expect(package.platform == nil)
    #expect(package.introduced == nil)
  }

  @Test("Introduced releases are keyed by platform raw value")
  func introducedReleasesKeysByPlatformRawValue() {
    let symbol = IndexedSymbol(
      usr: "s:1", title: "T", kind: .structure, pathComponents: ["T"],
      parentUSR: nil, introduced: [.iOS: SemanticVersion(major: 26)],
      isDeprecated: false
    )
    #expect(introducedReleases(symbol) == ["iOS": "26.0"])
  }

  @Test("Introduced releases skip unversioned platforms")
  func introducedReleasesSkipsUnversioned() {
    let symbol = IndexedSymbol(
      usr: "s:1", title: "T", kind: .structure, pathComponents: ["T"],
      parentUSR: nil,
      introduced: [
        .iOS: SemanticVersion(major: 26),
        .macOS: SemanticVersion(major: SemanticVersion.unversionedMajor),
      ],
      isDeprecated: false
    )
    #expect(introducedReleases(symbol) == ["iOS": "26.0"])
  }

  @Test("Symbol node output nests child symbols")
  func symbolNodeOutputNestsChildren() {
    let child = SymbolTreeNode(
      symbol: IndexedSymbol(
        usr: "s:c", title: "P.c", kind: .property, pathComponents: ["P", "c"],
        parentUSR: "s:p", introduced: [.iOS: SemanticVersion(major: 26)],
        isDeprecated: false
      ),
      isMatch: true, children: []
    )
    let parent = SymbolTreeNode(
      symbol: IndexedSymbol(
        usr: "s:p", title: "P", kind: .structure, pathComponents: ["P"],
        parentUSR: nil, introduced: [:], isDeprecated: false
      ),
      isMatch: false, children: [child]
    )

    let output = SymbolNodeOutput(parent)
    #expect(!output.match)
    #expect(output.children.count == 1)
    #expect(output.children.first?.match == true)
  }

  @Test("Diff summary output maps the per-category counts", .tags(.diffing))
  func diffSummaryOutputMapsCounts() {
    let output = DiffSummaryOutput(
      FrameworkDiffSummary(
        moduleName: "PencilKit", addedCount: 3, removedCount: 1,
        changedCount: 2
      )
    )
    #expect(output.module == "PencilKit")
    #expect(output.added == 3)
    #expect(output.removed == 1)
    #expect(output.changed == 2)
  }

  @Test(
    "Symbol change output sorts reasons and keeps both records",
    .tags(.diffing)
  )
  func symbolChangeOutputSortsReasonsAndKeepsBothRecords() {
    let old = IndexedSymbol(
      usr: "s:f-v1", title: "T.f(_:)", kind: .method,
      pathComponents: ["T", "f(_:)"], parentUSR: nil,
      introduced: [.iOS: SemanticVersion(major: 26)], isDeprecated: false
    )
    let new = IndexedSymbol(
      usr: "s:f-v2", title: "T.f(_:)", kind: .method,
      pathComponents: ["T", "f(_:)"], parentUSR: nil,
      introduced: [.iOS: SemanticVersion(major: 26)], isDeprecated: true
    )

    let output = SymbolChangeOutput(
      SymbolChange(old: old, new: new, reasons: [.signature, .deprecation])
    )

    #expect(output.reasons == ["deprecation", "signature"])
    #expect(output.old.usr == "s:f-v1")
    #expect(output.new.usr == "s:f-v2")
    #expect(output.new.deprecated)
  }

  // MARK: - Argument parsing

  @Test("Frameworks command parses select and format options")
  func frameworksParsesSelectAndFormat() throws {
    let command = try Frameworks.parse([
      "--select", "ios:26.0", "--format", "json",
    ])
    #expect(command.releases.count == 1)
    #expect(command.options.format == .json)
  }

  @Test("Search command parses term, kind, and limit")
  func searchParsesTermKindAndLimit() throws {
    let command = try Search.parse([
      "stroke", "--kind", SymbolKind.property.rawValue, "--limit", "10",
    ])
    #expect(command.term == "stroke")
    #expect(command.kinds.count == 1)
    #expect(command.limit == 10)
  }

  @Test("Summarize command parses select and eval flag")
  func summarizeParsesSelectAndEvalFlag() throws {
    let command = try Summarize.parse([
      "WebKit", "--select", "ios:26.5", "--eval",
    ])
    #expect(command.module == "WebKit")
    #expect(command.releases.count == 1)
    #expect(command.eval)
    #expect(!(try Summarize.parse(["WebKit", "--select", "ios:26.5"]).eval))
  }

  @Test("Query commands parse an explicit Xcode build")
  func queryCommandsParseAnExplicitXcodeBuild() throws {
    #expect(
      try Search.parse(["stroke", "--xcode", "17F113"])
        .indexSelection.xcodeBuild == "17F113"
    )
    #expect(
      try Frameworks.parse(["--select", "ios:26.0", "--xcode", "17F113"])
        .indexSelection.xcodeBuild == "17F113"
    )
    #expect(try Platforms.parse([]).indexSelection.xcodeBuild == nil)
  }

  @Test("Diff command parses builds and an optional module", .tags(.diffing))
  func diffParsesBuildsAndOptionalModule() throws {
    let summary = try Diff.parse(["--from", "26A1"])
    #expect(summary.fromBuild == "26A1")
    #expect(summary.toBuild == nil)
    #expect(summary.module == nil)

    let scoped = try Diff.parse([
      "PencilKit", "--from", "26A1", "--to", "27A1",
    ])
    #expect(scoped.module == "PencilKit")
    #expect(scoped.toBuild == "27A1")

    #expect(throws: (any Error).self) { try Diff.parse([]) }
  }

  // MARK: - Exit codes

  @Test("Fail returns the given exit code")
  func failReturnsTheGivenExitCode() {
    let code = fail(
      "missing", code: ExitStatus.notFound, name: "notFound", format: .json
    )
    #expect(code == ExitCode(ExitStatus.notFound))
  }

  // MARK: - Xcode registry

  @Test("Xcode reference resolves by build number", .tags(.xcodes))
  func resolvesXcodeReferenceByBuildNumber() {
    let xcode = Self.installation("Xcode", 27, build: "27A100")
    let entry = XcodeEntry(
      applicationURL: xcode.applicationURL, installation: xcode,
      isManuallyAdded: false, isDefault: true, isSystemSelected: true
    )
    #expect(
      resolveXcodeReference("27A100", in: [entry]) == xcode.applicationURL
    )
    #expect(resolveXcodeReference("nope", in: [entry]) == nil)
  }

  @Test("Xcode reference resolves by path", .tags(.xcodes))
  func resolvesXcodeReferenceByPath() {
    let url = resolveXcodeReference("/Applications/Xcode-beta.app", in: [])
    #expect(url?.path(percentEncoded: false) == "/Applications/Xcode-beta.app")
  }

  @Test("File URL expands tilde and absolutizes the path", .tags(.xcodes))
  func fileURLExpandsTildeAndAbsolutizes() {
    #expect(
      fileURL(forArgument: "/Applications/Xcode.app")
        .path(percentEncoded: false) == "/Applications/Xcode.app"
    )
    let home = fileURL(forArgument: "~/Xcode.app").path(percentEncoded: false)
    #expect(home.hasPrefix(NSHomeDirectory()))
    #expect(home.hasSuffix("/Xcode.app"))
  }

  @Test("Xcode list item maps a valid entry", .tags(.xcodes))
  func xcodeListItemMapsAValidEntry() {
    let xcode = Self.installation("Xcode-beta", 27, build: "27A100")
    let item = XcodeListItem(
      XcodeEntry(
        applicationURL: xcode.applicationURL, installation: xcode,
        isManuallyAdded: true, isDefault: true, isSystemSelected: false
      )
    )
    #expect(item.build == "27A100")
    #expect(item.version == "27.0")
    #expect(item.isDefault)
    #expect(item.manuallyAdded)
    #expect(!item.broken)
  }

  @Test("Xcode list item marks a broken entry", .tags(.xcodes))
  func xcodeListItemMarksABrokenEntry() {
    let item = XcodeListItem(
      XcodeEntry(
        applicationURL: URL(filePath: "/Applications/Gone.app"),
        installation: nil, isManuallyAdded: true, isDefault: false,
        isSystemSelected: false
      )
    )
    #expect(item.broken)
    #expect(item.build == nil)
    #expect(xcodeListLine(item).contains("(missing)"))
  }

  @Test("Xcode use requires exactly one target", .tags(.xcodes))
  func xcodeUseRequiresExactlyOneTarget() throws {
    #expect(throws: (any Error).self) { try XcodeUse.parse([]) }
    #expect(throws: (any Error).self) {
      try XcodeUse.parse(["--system", "27A100"])
    }
    #expect(try XcodeUse.parse(["--system"]).system)
    #expect(try XcodeUse.parse(["27A100"]).reference == "27A100")
  }

  @Test("Xcode add parses a path", .tags(.xcodes))
  func xcodeAddParsesAPath() throws {
    #expect(
      try XcodeAdd.parse(["/Applications/Xcode.app"]).path
        == "/Applications/Xcode.app"
    )
  }

  // MARK: - Helpers

  static func installation(_ name: String, _ major: Int, build: String)
    -> XcodeInstallation
  {
    let app = URL(filePath: "/Applications/\(name).app")
    return XcodeInstallation(
      applicationURL: app,
      developerDirURL: app.appending(path: "Contents/Developer"),
      version: SemanticVersion(major: major), build: build, isBeta: false
    )
  }
}
