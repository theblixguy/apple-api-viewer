import SwiftUI

struct AvailabilityPill: View {
  let content: Text
  var tint: Color?

  init(text: String, tint: Color? = nil) {
    content = Text(text)
    self.tint = tint
  }

  init(_ content: Text, tint: Color? = nil) {
    self.content = content
    self.tint = tint
  }

  var body: some View {
    let glass: Glass = tint.map { .regular.tint($0) } ?? .regular
    content
      .font(.callout)
      // The pill keeps its ideal size. Without this, the flow layout can
      // measure a long pill one line tall while its text wraps, and the
      // capsule clips the bottom.
      .fixedSize()
      .padding(.horizontal, Spacing.medium)
      .padding(.vertical, Spacing.xSmall)
      .glassEffect(glass, in: Capsule())
  }
}
