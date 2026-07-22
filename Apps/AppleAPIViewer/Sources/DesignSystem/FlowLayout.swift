import SwiftUI

struct FlowLayout: Layout {
  var spacing: CGFloat = Spacing.small
  var lineSpacing: CGFloat = Spacing.small

  struct Cache {
    var sizes: [CGSize]
  }

  func makeCache(subviews: Subviews) -> Cache {
    Cache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
  }

  func updateCache(_ cache: inout Cache, subviews: Subviews) {
    cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
  }

  func sizeThatFits(
    proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
  ) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var widestRow: CGFloat = 0

    for size in cache.sizes {
      let width = min(size.width, maxWidth)
      if x > 0, x + width > maxWidth {
        widestRow = max(widestRow, x - spacing)
        x = 0
        y += rowHeight + lineSpacing
        rowHeight = 0
      }
      x += width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    widestRow = max(widestRow, x - spacing)
    return CGSize(width: min(widestRow, maxWidth), height: y + rowHeight)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
    cache: inout Cache
  ) {
    var x = bounds.minX
    var y = bounds.minY
    var rowHeight: CGFloat = 0

    for (subview, size) in zip(subviews, cache.sizes) {
      let width = min(size.width, bounds.width)
      if x > bounds.minX, x + width > bounds.maxX {
        x = bounds.minX
        y += rowHeight + lineSpacing
        rowHeight = 0
      }
      subview.place(
        at: CGPoint(x: x, y: y),
        anchor: .topLeading,
        proposal: ProposedViewSize(width: width, height: size.height)
      )
      x += width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
