import AppleAPIViewerCore
import CoreModel
import SwiftUI

struct PlatformFilterPanel: View {
  let browser: BrowserModel

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.small) {
      Text("Show APIs in")
        .font(Typography.sectionLabel)
        .foregroundStyle(.secondary)
        .textCase(.uppercase)

      ForEach(browser.supportedPlatforms) { platform in
        HStack(spacing: Spacing.small) {
          Text(platform.displayName)
            .font(.callout)
            .frame(width: Metrics.platformLabelWidth, alignment: .leading)
            .foregroundStyle(
              browser.isIndexed(platform) ? .primary : .secondary
            )

          Spacer(minLength: 0)

          if browser.isIndexed(platform) {
            VersionFilterControl(browser: browser, platform: platform)
          } else {
            Text("Not installed")
              .font(.caption)
              .foregroundStyle(.tertiary)
              .help(
                "Download the \(platform.displayName) SDK in Xcode ▸ Settings ▸ Components, then re-index (⌘⇧R)."
              )
          }
        }
      }
    }
    .padding(Spacing.medium)
    .background(.bar)
  }
}
