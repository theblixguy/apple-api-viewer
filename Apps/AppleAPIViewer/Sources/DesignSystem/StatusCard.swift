import AppleAPIViewerCore
import SwiftUI

struct StatusCard<Accessory: View>: View {
  let systemImage: String
  let title: LocalizedStringKey
  let message: Text
  @ViewBuilder var accessory: Accessory

  var body: some View {
    VStack(spacing: Spacing.large) {
      Image(systemName: systemImage)
        .font(.system(size: IconSize.statusGlyph))
        .foregroundStyle(.tint)
        .accessibilityHidden(true)
      Text(title).font(Typography.cardTitle)
      message
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: Metrics.cardContentMaxWidth)
      accessory.padding(.top, Spacing.xSmall)
    }
    .glassCard()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}
