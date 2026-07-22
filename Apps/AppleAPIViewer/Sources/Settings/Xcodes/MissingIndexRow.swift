import AppleAPIViewerCore
import IndexOrchestration
import IndexStore
import SwiftUI

struct MissingIndexRow: View {
  let indexed: IndexedSource
  let coordinator: IndexCoordinator

  @State private var confirmingDeletion = false

  private var isChecked: Bool {
    coordinator.selectedMissingIndex == indexed.id
  }

  private var sizeLabel: String {
    indexed.estimatedByteCount.formatted(.byteCount(style: .file))
  }

  var body: some View {
    HStack(spacing: Spacing.small) {
      Button(action: select) {
        Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(
            isChecked ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
          )
      }
      .buttonStyle(.plain)
      .help("Browse this index")
      .accessibilityLabel(
        "Browse the index for \(indexed.source.displayName)"
      )

      VStack(alignment: .leading, spacing: 2) {
        Text(indexed.source.displayName)
        Text("Its Xcode is gone, so the index browses but can't be rebuilt.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Text(sizeLabel)
        .font(.callout)
        .monospacedDigit()
        .foregroundStyle(.secondary)

      Menu {
        if !isChecked {
          Button("Browse Index", action: select)
        }
        Button("Delete Index…", role: .destructive) {
          confirmingDeletion = true
        }
        .disabled(coordinator.isMutatingIndex)
      } label: {
        Image(systemName: "ellipsis.circle")
      }
      .buttonStyle(.borderless)
      .menuIndicator(.hidden)
      .fixedSize()
      .accessibilityLabel("Actions for \(indexed.source.displayName)")
      .confirmationDialog(
        "Delete the index for \(indexed.source.displayName)?",
        isPresented: $confirmingDeletion, titleVisibility: .visible
      ) {
        Button("Delete index", role: .destructive) {
          Task { await coordinator.deleteMissingIndex(indexed) }
        }
      } message: {
        Text(
          "This frees about \(sizeLabel). Its Xcode is gone, so the index can't be rebuilt."
        )
      }
    }
    .padding(.vertical, 2)
    .contentShape(.rect)
    .onTapGesture { select() }
    .accessibilityAction { select() }
  }

  private func select() {
    guard !isChecked else { return }
    Task { await coordinator.browseMissingIndex(indexed) }
  }
}
