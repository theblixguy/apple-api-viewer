import SymbolGraphIndex
import Testing
@testable import AppleAPIViewerCore

@Suite("Symbol display", .tags(.display))
struct SymbolDisplayTests {
  @Test(
    "Labels known kinds",
    arguments: [
      (SymbolKind.class, "Class"),
      (.enumCase, "Enum case"),
      (.typeMethod, "Type method"),
    ]
  )
  func labelsKnownKinds(_ kind: SymbolKind, _ label: String) {
    #expect(SymbolDisplay.label(for: kind) == label)
  }

  @Test("Every kind has an image", arguments: SymbolKind.allCases)
  func everyKindHasAnImage(_ kind: SymbolKind) {
    #expect(!SymbolDisplay.systemImageName(for: kind).isEmpty)
  }
}
