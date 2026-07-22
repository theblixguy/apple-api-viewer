import SwiftUI

struct AvailabilityPill: View {
  let text: String
  var tint: Color?

  var body: some View {
    let glass: Glass = tint.map { .regular.tint($0) } ?? .regular
    Text(text)
      .font(.callout)
      .padding(.horizontal, Spacing.medium)
      .padding(.vertical, Spacing.xSmall)
      .glassEffect(glass, in: Capsule())
  }
}
