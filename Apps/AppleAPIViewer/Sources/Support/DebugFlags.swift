#if DEBUG
  nonisolated enum DebugFlags {
    // The app can reset the TipKit datastore only before `Tips.configure()` runs.
    // This flag marks the datastore for reset at the next launch.
    static let resetTipsAtLaunch = "debug.resetTipsAtLaunch"
  }
#endif
