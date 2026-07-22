import CoreModel
import SwiftUI

struct IndexingView: View {
  let progress: IndexingProgress
  let xcode: String?
  let isPaused: Bool
  let onPauseResume: () -> Void
  let onCancel: () -> Void

  var body: some View {
    VStack(spacing: Spacing.large) {
      Image(systemName: "gearshape.2")
        .font(.system(size: IconSize.statusGlyph))
        .foregroundStyle(.tint)
        .symbolEffect(.pulse, isActive: !isPaused)
        .accessibilityHidden(true)

      Text(isPaused ? "Indexing paused" : "Indexing SDK symbols")
        .font(Typography.cardTitle)

      if let xcode {
        Text(xcode)
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Group {
        if progress.phase == .saving {
          ProgressView { Text("Saving index…") }
        } else if progress.total > 0 {
          ProgressView(value: progress.fractionCompleted) {
            Text(
              "\(progress.completed) of ^[\(progress.total) modules](inflect: true)"
            )
            .monospacedDigit()
          }
        } else {
          ProgressView { Text("Finding modules…") }
        }
      }

      Text(progress.currentModule ?? " ")
        .font(Typography.codePath)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
        .truncationMode(.middle)

      HStack(spacing: Spacing.small) {
        Button(isPaused ? "Resume" : "Pause", action: onPauseResume)
          .buttonStyle(.bordered)
        Button("Cancel", action: onCancel)
          .buttonStyle(.bordered)
      }
      .padding(.top, Spacing.xSmall)
    }
    .frame(width: Metrics.cardWidth)
    .glassCard()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}

#Preview("Indexing") {
  IndexingView(
    progress: IndexingProgress(
      completed: 128, total: 310, currentModule: "PencilKit"
    ),
    xcode: "Xcode 27.0 beta (27A5194q)",
    isPaused: false,
    onPauseResume: {},
    onCancel: {}
  )
  .frame(width: 640, height: 460)
}
