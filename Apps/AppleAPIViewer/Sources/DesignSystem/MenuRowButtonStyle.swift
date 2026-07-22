import SwiftUI

struct MenuRowButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    MenuRow(configuration: configuration)
  }

  private struct MenuRow: View {
    let configuration: Configuration
    @State private var isHovering = false

    var body: some View {
      configuration.label
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, Spacing.xSmall + 1)
        .contentShape(.rect)
        .background(
          isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
          in: .rect(cornerRadius: CornerRadius.menuRow)
        )
        .opacity(configuration.isPressed ? 0.7 : 1)
        .onHover { isHovering = $0 }
    }
  }
}
