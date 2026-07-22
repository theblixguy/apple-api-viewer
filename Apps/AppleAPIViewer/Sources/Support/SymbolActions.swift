import AppKit
import SwiftUI

func copyToPasteboard(_ string: String) {
  NSPasteboard.general.clearContents()
  NSPasteboard.general.setString(string, forType: .string)
}

@ViewBuilder
func symbolActions(name: String, url: URL, openURL: OpenURLAction) -> some View
{
  Button("Open in Browser", systemImage: "safari") { openURL(url) }
  Divider()
  Button("Copy Documentation URL", systemImage: "link") {
    copyToPasteboard(url.absoluteString)
  }
  Button("Copy Name", systemImage: "textformat") { copyToPasteboard(name) }
}
