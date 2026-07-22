import SwiftUI

struct BannerAction {
  let title: LocalizedStringKey
  let run: () -> Void
}

struct Banner: View {
  let icon: String
  let message: Text
  var action: BannerAction?
  var onDismiss: (() -> Void)?

  var body: some View {
    HStack(spacing: Spacing.medium) {
      Image(systemName: icon)
        .accessibilityHidden(true)
      message
        .font(.callout)
      Spacer(minLength: Spacing.small)
      if let action {
        Button(action.title, action: action.run)
          .buttonStyle(.bordered)
      }
      if let onDismiss {
        Button("Dismiss", systemImage: "xmark", action: onDismiss)
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
      }
    }
    .padding(.horizontal, Spacing.large)
    .padding(.vertical, Spacing.small)
    .glassEffect(.regular, in: Capsule())
    .padding(.horizontal)
  }
}
