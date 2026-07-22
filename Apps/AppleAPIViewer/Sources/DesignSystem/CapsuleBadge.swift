import SwiftUI

struct CapsuleBadge: View {
  let text: String

  var body: some View {
    Text(text)
      .font(Typography.badge)
      .padding(.horizontal, Spacing.xSmall)
      .padding(.vertical, Spacing.xxSmall)
      .background(.tint, in: .capsule)
      .foregroundStyle(.white)
      .accessibilityLabel(text.capitalized)
  }
}
