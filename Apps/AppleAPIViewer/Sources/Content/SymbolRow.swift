import AppleAPIViewerCore
import SwiftUI
import SymbolGraphIndex

struct SymbolRow: View {
  let node: SymbolTreeNode

  var body: some View {
    Label {
      HStack(spacing: Spacing.small) {
        Text(node.symbol.name)
          .foregroundStyle(node.isMatch ? Color.primary : Color.secondary)
        if node.isMatch {
          NewBadge()
        }
      }
    } icon: {
      Image(systemName: SymbolDisplay.systemImageName(for: node.symbol.kind))
        .foregroundStyle(node.isMatch ? Color.accentColor : Color.secondary)
        .accessibilityHidden(true)
    }
    .help(SymbolDisplay.label(for: node.symbol.kind))
    .accessibilityElement(children: .combine)
    .accessibilityHint(SymbolDisplay.label(for: node.symbol.kind))
  }
}

struct NewBadge: View {
  var body: some View {
    CapsuleBadge(text: "NEW")
  }
}
