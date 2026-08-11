import AppleAPIViewerCore
import SwiftUI
import SymbolGraphIndex

struct DiffSymbolRow: View {
  let node: SymbolTreeNode
  let category: DiffCategory
  let reasons: Set<SymbolChange.Reason>?

  var body: some View {
    Label {
      VStack(alignment: .leading) {
        Text(node.symbol.name)
          .foregroundStyle(node.isMatch ? Color.primary : Color.secondary)
        if let reasons, !reasons.isEmpty {
          Text(Self.reasonsLabel(reasons))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    } icon: {
      Image(systemName: SymbolDisplay.systemImageName(for: node.symbol.kind))
        .foregroundStyle(node.isMatch ? categoryColor : Color.secondary)
        .accessibilityHidden(true)
    }
    .help(SymbolDisplay.label(for: node.symbol.kind))
    .accessibilityElement(children: .combine)
    .accessibilityHint(SymbolDisplay.label(for: node.symbol.kind))
  }

  // MARK: - Private

  private var categoryColor: Color {
    switch category {
    case .added: .green
    case .removed: .red
    case .changed: .orange
    }
  }

  private static func reasonsLabel(_ reasons: Set<SymbolChange.Reason>)
    -> String
  {
    reasons
      .sorted { $0.rawValue < $1.rawValue }
      .map { reason in
        switch reason {
        case .signature: String(localized: "Signature changed")
        case .deprecation: String(localized: "Deprecation changed")
        case .availability: String(localized: "Availability changed")
        }
      }
      .joined(separator: ", ")
  }
}
