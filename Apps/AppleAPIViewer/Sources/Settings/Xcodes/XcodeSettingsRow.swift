import AppleAPIViewerCore
import IndexOrchestration
import IndexStore
import SwiftUI

struct XcodeSettingsRow: View {
  let entry: XcodeEntry
  let coordinator: IndexCoordinator

  @State private var confirmingIndexDeletion = false
  @State private var confirmingRemoval = false

  var body: some View {
    HStack(spacing: Spacing.small) {
      selectionIndicator

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
        Text(entry.applicationURL.path(percentEncoded: false))
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
        if !tags.isEmpty {
          HStack(spacing: Spacing.xSmall) {
            ForEach(tags, id: \.self) { tag in
              Text(tag)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.xSmall)
                .padding(.vertical, 1)
                .background(.quaternary, in: Capsule())
            }
          }
        }
      }

      Spacer()

      if let indexed {
        Text(indexed.estimatedByteCount.formatted(.byteCount(style: .file)))
          .font(.callout)
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }

      if hasMenuItems {
        actionsMenu
      }
    }
    .padding(.vertical, 2)
    .contentShape(.rect)
    .onTapGesture { select() }
    .accessibilityAction { select() }
  }

  private var offersUseAction: Bool {
    !entry.isBroken && !isPinnedChoice && !isInUseViaAutomatic
  }

  private var hasMenuItems: Bool {
    offersUseAction || indexed != nil || entry.isManuallyAdded
  }

  private var indexed: IndexedSource? {
    coordinator.indexedSource(for: entry)
  }

  private var isPinnedChoice: Bool {
    entry.isDefault && !coordinator.isFollowingSystemXcode
      && coordinator.selectedMissingIndex == nil
  }

  private var isInUseViaAutomatic: Bool {
    entry.isDefault && coordinator.isFollowingSystemXcode
      && coordinator.selectedMissingIndex == nil
  }

  // MARK: - Subviews

  @ViewBuilder private var selectionIndicator: some View {
    if entry.isBroken {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.title3)
        .foregroundStyle(.orange)
        .accessibilityLabel("\(title) is missing")
    } else {
      Button(action: select) {
        Image(systemName: isPinnedChoice ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(
            isPinnedChoice ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
          )
      }
      .buttonStyle(.plain)
      .help("Build the index from this Xcode")
      .accessibilityLabel("Use \(title) for indexing")
    }
  }

  private var actionsMenu: some View {
    Menu {
      if offersUseAction {
        Button("Use for Indexing", action: select)
      }
      if indexed != nil {
        Button("Delete Index…", role: .destructive) {
          confirmingIndexDeletion = true
        }
        .disabled(coordinator.isMutatingIndex)
      }
      if entry.isManuallyAdded {
        if offersUseAction || indexed != nil {
          Divider()
        }
        Button("Remove from List…", role: .destructive) {
          confirmingRemoval = true
        }
      }
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    .buttonStyle(.borderless)
    .menuIndicator(.hidden)
    .fixedSize()
    .accessibilityLabel("Actions for \(title)")
    .confirmationDialog(
      "Delete the index for \(title)?",
      isPresented: $confirmingIndexDeletion, titleVisibility: .visible
    ) {
      Button("Delete index", role: .destructive) {
        Task { await coordinator.deleteIndex(for: entry) }
      }
    } message: {
      if entry.isDefault {
        Text(
          "This frees about \(sizeLabel). The index rebuilds immediately, since this Xcode is being browsed."
        )
      } else {
        Text(
          "This frees about \(sizeLabel). Browsing this Xcode again rebuilds it."
        )
      }
    }
    .confirmationDialog(
      "Remove \(title) from the list?",
      isPresented: $confirmingRemoval, titleVisibility: .visible
    ) {
      Button("Remove from list", role: .destructive) {
        Task { await coordinator.removeXcode(entry) }
      }
    } message: {
      if entry.isBroken {
        Text("Add it back any time with Add Xcode.")
      } else {
        Text(
          "Its stored index is removed too. Add it back any time with Add Xcode."
        )
      }
    }
  }

  private func select() {
    guard !entry.isBroken, !isPinnedChoice else { return }
    Task { await coordinator.chooseDefaultXcode(entry) }
  }

  private var sizeLabel: String {
    indexed?.estimatedByteCount.formatted(.byteCount(style: .file)) ?? ""
  }

  private var title: String {
    entry.installation?.displayName ?? entry.applicationURL.lastPathComponent
  }

  private var tags: [String] {
    var result: [String] = []
    if isInUseViaAutomatic { result.append("In use") }
    if entry.isBroken { result.append("Missing") }
    if entry.isManuallyAdded { result.append("Added") }
    return result
  }
}
