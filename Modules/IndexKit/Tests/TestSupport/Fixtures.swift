import CoreModel
import SymbolGraphIndex

package let sdk = Source(
  id: "apple-sdk:27A5194q", kind: .appleSDK, displayName: "Xcode 27.0"
)

package func iOS(_ major: Int, _ minor: Int = 0) -> [ApplePlatform:
  SemanticVersion]
{
  [.iOS: SemanticVersion(major: major, minor: minor)]
}

package func pencilKit() -> FrameworkIndex {
  FrameworkIndex(
    moduleName: "PencilKit",
    symbols: [
      IndexedSymbol(
        usr: "s:PKStroke", title: "PKStroke", kind: .structure,
        pathComponents: ["PKStroke"], parentUSR: nil,
        introduced: iOS(14), isDeprecated: false
      ),
      IndexedSymbol(
        usr: "s:RenderState", title: "PKStroke.RenderState", kind: .structure,
        pathComponents: ["PKStroke", "RenderState"], parentUSR: "s:PKStroke",
        introduced: [
          .iOS: SemanticVersion(major: 27),
          .macOS: SemanticVersion(major: 27),
        ],
        isDeprecated: false, summary: "The render details of a stroke."
      ),
      IndexedSymbol(
        usr: "s:grainOffset", title: "PKStroke.RenderState.grainOffset",
        kind: .property,
        pathComponents: ["PKStroke", "RenderState", "grainOffset"],
        parentUSR: "s:RenderState",
        introduced: iOS(27), isDeprecated: false
      ),
      IndexedSymbol(
        usr: "s:Visibility", title: "PKToolPickerVisibility",
        kind: .enumeration,
        pathComponents: ["PKToolPickerVisibility"], parentUSR: nil,
        introduced: iOS(26), isDeprecated: false
      ),
    ]
  )
}
