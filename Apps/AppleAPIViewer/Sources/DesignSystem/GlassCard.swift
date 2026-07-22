import SwiftUI

extension View {
  func glassCard() -> some View {
    padding(Spacing.huge)
      .glassEffect(
        .regular, in: RoundedRectangle(cornerRadius: CornerRadius.card)
      )
  }
}
