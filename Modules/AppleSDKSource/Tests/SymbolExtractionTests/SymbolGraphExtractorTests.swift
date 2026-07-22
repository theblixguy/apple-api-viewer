import CoreModel
import Foundation
import SDKDiscovery
import Testing
@testable import SymbolExtraction

@Suite("Symbol graph extractor", .tags(.extraction))
struct SymbolGraphExtractorUnitTests {
  @Test(
    "Cross-import overlays are identified by module name",
    arguments: [
      ("_AppIntents_SwiftUI", true),
      ("_Concurrency", true),
      ("PencilKit", false),
      ("SwiftUI", false),
    ]
  )
  func identifiesCrossImportOverlays(moduleName: String, isOverlay: Bool) {
    #expect(
      SymbolGraphExtractor.isCrossImportOverlay(moduleName: moduleName)
        == isOverlay
    )
  }

  @Test("Symbol files are filtered to the requested module")
  func selectsOnlyThisModulesSymbolFiles() {
    let entries = [
      "PencilKit.symbols.json", // primary, included
      "PencilKit@UIKit.symbols.json", // extension overlay, included
      "_PencilKit_FoundationModels@PencilKit.symbols.json", // cross-import, in
      "_Foo_Bar@Other.symbols.json", // cross-import, other module
      "Other.symbols.json", // different module, excluded
      "PencilKit.txt", // not a symbol graph, excluded
    ].map { URL(filePath: "/tmp/\($0)") }

    let produced =
      SymbolGraphExtractor
        .producedFiles(forModule: "PencilKit", among: entries)
        .map(\.lastPathComponent)
    #expect(
      produced == [
        "PencilKit.symbols.json", "PencilKit@UIKit.symbols.json",
        "_PencilKit_FoundationModels@PencilKit.symbols.json",
      ]
    )
  }
}

@Suite(
  "Symbol graph extractor enumeration",
  .tags(.extraction),
  .enabled(if: SDKDiscovery.latestXcode() != nil)
)
struct SymbolGraphExtractorEnumerationTests {
  @Test("Extractable modules list real frameworks and exclude overlays")
  func listsRealFrameworksAndExcludesOverlays() throws {
    let xcode = try #require(SDKDiscovery.latestXcode())
    let iOSSDK = try #require(
      SDKDiscovery.sdks(in: xcode).first { $0.platform == .iOS }
    )

    let modules = SymbolGraphExtractor.extractableModules(in: iOSSDK)
    #expect(modules.contains("UIKit"))
    #expect(modules.contains("SwiftUI"))
    #expect(modules.contains("PencilKit"))
    #expect(modules.allSatisfy { !$0.hasPrefix("_") })
  }
}

@Suite(
  "Symbol graph extractor extraction",
  .tags(.extraction),
  .enabled(
    if: ProcessInfo.processInfo.environment["RUN_EXTRACTION_TESTS"] != nil
      && SDKDiscovery.latestXcode() != nil
  )
)
struct SymbolGraphExtractorExtractionTests {
  @Test("Extraction produces a parseable symbol graph")
  func extractsParseableSymbolGraph() async throws {
    let xcode = try #require(SDKDiscovery.latestXcode())
    let iOSSDK = try #require(
      SDKDiscovery.sdks(in: xcode).first { $0.platform == .iOS }
    )

    let output = URL(filePath: NSTemporaryDirectory()).appending(
      path: "sgextract-\(UUID().uuidString)"
    )
    defer { try? FileManager.default.removeItem(at: output) }

    let files = try await SymbolGraphExtractor.extract(
      xcode: xcode, module: "PencilKit", sdk: iOSSDK, into: output
    )

    let primary = try #require(
      files.first { $0.lastPathComponent == "PencilKit.symbols.json" }
    )
    let object =
      try JSONSerialization.jsonObject(with: Data(contentsOf: primary))
        as? [String: Any]
    #expect(object?["symbols"] != nil)
  }
}
