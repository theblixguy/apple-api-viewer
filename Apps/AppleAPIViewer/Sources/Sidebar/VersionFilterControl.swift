import AppleAPIViewerCore
import CoreModel
import SwiftUI

struct VersionFilterControl: View {
  let browser: BrowserModel
  let platform: ApplePlatform
  @State private var isPresented = false

  var body: some View {
    Button {
      isPresented = true
    } label: {
      HStack(spacing: Spacing.xSmall) {
        Text(browser.selectionLabel(for: platform))
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(width: Metrics.versionButtonLabelWidth, alignment: .leading)
        Image(systemName: "chevron.down")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .buttonStyle(.bordered)
    .accessibilityLabel("\(platform.displayName) versions")
    .accessibilityValue(browser.selectionLabel(for: platform))
    .popover(isPresented: $isPresented, arrowEdge: .bottom) {
      VersionSelectionList(browser: browser, platform: platform)
    }
  }
}

private struct VersionSelectionList: View {
  let browser: BrowserModel
  let platform: ApplePlatform

  var body: some View {
    let releases = browser.releasesByPlatform[platform] ?? []
    VStack(alignment: .leading, spacing: Spacing.small) {
      HStack {
        Text(platform.displayName).font(.headline)
        Spacer()
        Button("Clear") { browser.clearSelection(for: platform) }
          .buttonStyle(.borderless)
          .disabled(browser.chosenReleases[platform]?.isEmpty ?? true)
      }

      ScrollView {
        LazyVStack(alignment: .leading, spacing: Spacing.xSmall) {
          ForEach(releases, id: \.self) { release in
            Toggle(
              BrowserModel.versionLabel(release), isOn: binding(for: release)
            )
          }
        }
      }
      .frame(
        height: min(
          CGFloat(releases.count) * Metrics.versionRowHeight,
          Metrics.versionPopoverHeight
        )
      )
      .scrollBounceBehavior(.basedOnSize)
    }
    .padding(Spacing.medium)
    .frame(width: Metrics.versionPopoverWidth)
  }

  private func binding(for release: SemanticVersion) -> Binding<Bool> {
    Binding(
      get: { browser.isSelected(platform, release) },
      set: { _ in browser.toggle(platform, release) }
    )
  }
}
