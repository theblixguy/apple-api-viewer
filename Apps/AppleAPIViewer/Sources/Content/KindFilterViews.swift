import AppleAPIViewerCore
import SwiftUI
import SymbolGraphIndex

struct KindFilterControl: View {
  let browser: BrowserModel
  @State private var isPresented = false

  var body: some View {
    Button {
      isPresented.toggle()
    } label: {
      Label(
        "Filter by kind",
        systemImage: browser.kindFilter == nil
          ? "line.3.horizontal.decrease.circle"
          : "line.3.horizontal.decrease.circle.fill"
      )
    }
    .help("Filter by symbol kind")
    .popover(isPresented: $isPresented, arrowEdge: .bottom) {
      KindFilterList(browser: browser)
    }
  }
}

private struct KindFilterList: View {
  let browser: BrowserModel

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.small) {
      HStack {
        Text("Kind").font(.headline)
        Spacer()
        Button("Clear") { browser.clearKinds() }
          .buttonStyle(.borderless)
          .disabled(browser.selectedKinds.isEmpty)
      }

      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
          ForEach(SymbolKind.allCases, id: \.self) { kind in
            Toggle(isOn: binding(for: kind)) {
              Label(
                SymbolDisplay.label(for: kind),
                systemImage: SymbolDisplay.systemImageName(for: kind)
              )
            }
          }
        }
        .labelReservedIconWidth(IconSize.kindGlyphWidth)
      }
      .frame(height: Metrics.kindPopoverHeight)
    }
    .padding(Spacing.medium)
    .frame(width: Metrics.kindPopoverWidth)
  }

  private func binding(for kind: SymbolKind) -> Binding<Bool> {
    Binding(
      get: { browser.isKindSelected(kind) },
      set: { _ in browser.toggleKind(kind) }
    )
  }
}
