import AppleAPIViewerCore
import SwiftUI
import SymbolGraphIndex

struct DiffEntryRow: View {
  let entry: DiffEntry

  var body: some View {
    Label {
      VStack(alignment: .leading) {
        Text(entry.symbol.title)
        if case let .changed(reasons) = entry.category {
          Text(Self.reasonsLabel(reasons))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    } icon: {
      Image(systemName: SymbolDisplay.systemImageName(for: entry.symbol.kind))
        .foregroundStyle(iconColor)
        .accessibilityHidden(true)
    }
    .help(SymbolDisplay.label(for: entry.symbol.kind))
    .accessibilityElement(children: .combine)
    .accessibilityHint(SymbolDisplay.label(for: entry.symbol.kind))
  }

  // MARK: - Private

  private var iconColor: Color {
    switch entry.category {
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
