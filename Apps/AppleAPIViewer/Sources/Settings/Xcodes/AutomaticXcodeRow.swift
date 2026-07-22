import AppleAPIViewerCore
import IndexOrchestration
import IndexStore
import SwiftUI

struct AutomaticXcodeRow: View {
  let coordinator: IndexCoordinator

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
      .help("Follow the Xcode that xcode-select points at")
      .accessibilityLabel("Follow the system Xcode selection")

      VStack(alignment: .leading, spacing: 2) {
        Text("Automatic")
        Text(caption)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(.vertical, 2)
    .contentShape(.rect)
    .onTapGesture { select() }
    .accessibilityAction { select() }
  }

  // MARK: - Private

  private var caption: String {
    guard let name = systemXcodeName else {
      return String(localized: "Follows the Xcode that xcode-select points at.")
    }
    return String(
      localized:
      "Follows the Xcode that xcode-select points at, currently \(name)."
    )
  }

  private var systemXcodeName: String? {
    coordinator.xcodeEntries.first { $0.isSystemSelected }.map {
      $0.installation?.displayName ?? $0.applicationURL.lastPathComponent
    }
  }

  private var isChecked: Bool {
    coordinator.isFollowingSystemXcode
      && coordinator.selectedMissingIndex == nil
  }

  private func select() {
    guard !isChecked else { return }
    Task { await coordinator.followSystemXcode() }
  }
}
