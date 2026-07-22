import AppleAPIViewerCore
import SwiftUI

// The Filter command menu and the menu bar filter share this view.
// This keeps the two menus identical.
struct PlatformFilterMenuContent: View {
  let browser: BrowserModel

  var body: some View {
    ForEach(browser.supportedPlatforms) { platform in
      Menu(platform.displayName) {
        if browser.isIndexed(platform) {
          Button("Off") { browser.clearSelection(for: platform) }
          Divider()
          ForEach(browser.releasesByPlatform[platform] ?? [], id: \.self) {
            release in
            Button {
              browser.toggle(platform, release)
            } label: {
              if browser.isSelected(platform, release) {
                Label(
                  BrowserModel.versionLabel(release), systemImage: "checkmark"
                )
              } else {
                Text(BrowserModel.versionLabel(release))
              }
            }
          }
        } else {
          Button("SDK Not Installed") {}.disabled(true)
        }
      }
    }
  }
}
