import AppIntents

struct AppleAPIViewerShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SearchAPIsIntent(),
      phrases: [
        "Search \(.applicationName)",
        "Search APIs in \(.applicationName)",
      ],
      shortTitle: "Search APIs",
      systemImageName: "magnifyingglass"
    )
    AppShortcut(
      intent: NewAPIsIntent(),
      phrases: [
        "What's new in \(.applicationName)",
        "Get new APIs from \(.applicationName)",
      ],
      shortTitle: "Get New APIs",
      systemImageName: "sparkles"
    )
    AppShortcut(
      intent: OpenFrameworkIntent(),
      phrases: [
        "Open a framework in \(.applicationName)",
      ],
      shortTitle: "Open Framework",
      systemImageName: "shippingbox"
    )
  }
}
