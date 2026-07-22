import CoreModel
import Dependencies
import Foundation
import SDKDiscovery

/// The shared set of Xcodes the index can build from.
///
/// Both the app and the command line tool read the same UserDefaults suite.
public struct XcodeRegistry: Sendable {
  /// The UserDefaults suite both front ends share.
  ///
  /// The name must not match any target's bundle identifier, since
  /// `UserDefaults(suiteName:)` rejects the running app's own identifier.
  public static let sharedSuiteName = "com.suyashsrijan.apple-api-viewer.shared"

  private let store: XcodeRegistryStore

  @Dependency(\.sdkDiscovery) private var discovery

  /// Creates a registry backed by the given UserDefaults suite.
  ///
  /// - Parameter suiteName: The suite to persist into, defaulting to the suite
  ///   both front ends share.
  public init(suiteName: String = XcodeRegistry.sharedSuiteName) {
    store = .userDefaults(suiteName: suiteName)
  }

  init(store: XcodeRegistryStore) {
    self.store = store
  }

  private enum Key {
    static let added = "xcode.addedPaths"
    static let preferred = "xcode.defaultPath"
  }

  // MARK: - Reading

  /// Returns the managed Xcodes, valid ones first by descending version and
  /// broken ones last.
  ///
  /// Scanning the application directories touches disk, so the call runs off
  /// the caller's actor.
  ///
  /// - Returns: The managed Xcodes, valid ones first by descending version
  ///   and broken ones last.
  @concurrent
  public func entries() async -> [XcodeEntry] {
    let auto = discovery.installedXcodes()
    let system = discovery.systemSelectedXcode()
    let manual = addedPaths().map { ($0, discovery.xcode(at: $0)) }
    let active = resolveActive(auto: auto, manual: manual, system: system)
    let activeKey = active.map { Self.key($0.applicationURL) }
    let systemKey = system.map { Self.key($0.applicationURL) }

    func makeEntry(
      _ url: URL, _ installation: XcodeInstallation?, manual: Bool
    ) -> XcodeEntry {
      XcodeEntry(
        applicationURL: url,
        installation: installation,
        isManuallyAdded: manual,
        isDefault: Self.key(url) == activeKey,
        isSystemSelected: Self.key(url) == systemKey
      )
    }

    var byPath: [String: XcodeEntry] = [:]
    for xcode in auto {
      byPath[Self.key(xcode.applicationURL)] = makeEntry(
        xcode.applicationURL, xcode, manual: false
      )
    }
    for (url, installation) in manual {
      byPath[Self.key(url)] = makeEntry(url, installation, manual: true)
    }
    if let active, byPath[Self.key(active.applicationURL)] == nil {
      byPath[Self.key(active.applicationURL)] = makeEntry(
        active.applicationURL, active, manual: false
      )
    }

    return byPath.values.sorted()
  }

  /// Returns the pinned default when it still resolves, otherwise the
  /// `xcode-select` Xcode, otherwise the newest known valid Xcode.
  ///
  /// Scanning the application directories touches disk, so the call runs off
  /// the caller's actor.
  ///
  /// - Returns: The active Xcode, or `nil` when no Xcode resolves.
  @concurrent
  public func activeXcode() async -> XcodeInstallation? {
    resolveActive(
      auto: discovery.installedXcodes(),
      manual: addedPaths().map { ($0, discovery.xcode(at: $0)) },
      system: discovery.systemSelectedXcode()
    )
  }

  /// Returns a Boolean value that indicates whether a default is pinned and
  /// still resolves to a usable Xcode.
  ///
  /// When this value is `false`, the index follows whichever Xcode
  /// `xcode-select` points at.
  ///
  /// - Returns: `true` when a default is pinned and still resolves to a
  ///   usable Xcode.
  public func hasPinnedDefault() -> Bool {
    guard let preferred = preferredPath() else { return false }
    return discovery.xcode(at: preferred) != nil
  }

  // MARK: - Writing

  /// Adds an Xcode to the registry by its application bundle.
  ///
  /// Adding an Xcode the application-directory scan already finds is a no-op.
  ///
  /// - Parameter applicationURL: The Xcode application bundle to add.
  /// - Throws: ``XcodeRegistryError/notAnXcode(_:)`` when the bundle is not a
  ///   usable Xcode.
  @concurrent
  public func add(applicationURL: URL) async throws(XcodeRegistryError) {
    guard discovery.xcode(at: applicationURL) != nil else {
      throw XcodeRegistryError.notAnXcode(applicationURL)
    }
    let key = Self.key(applicationURL)
    let isAlreadyAuto = discovery.installedXcodes().contains {
      Self.key($0.applicationURL) == key
    }
    guard !isAlreadyAuto else { return }

    var added = addedPaths()
    guard !added.contains(where: { Self.key($0) == key }) else { return }
    added.append(applicationURL.standardizedFileURL)
    setAddedPaths(added)
  }

  /// Removes a manually added Xcode from the registry.
  ///
  /// Removing an auto-detected Xcode does nothing, and removing the pinned
  /// default unpins it.
  ///
  /// - Parameter applicationURL: The Xcode application bundle to remove.
  public func remove(applicationURL: URL) {
    let key = Self.key(applicationURL)
    var added = addedPaths()
    guard let index = added.firstIndex(where: { Self.key($0) == key }) else {
      return
    }
    added.remove(at: index)
    setAddedPaths(added)

    if preferredPath().map(Self.key) == key {
      clearDefault()
    }
  }

  /// Pins the Xcode the index builds from.
  ///
  /// - Parameter applicationURL: The Xcode application bundle to build from.
  /// - Throws: ``XcodeRegistryError/notAnXcode(_:)`` when the bundle is not a
  ///   usable Xcode.
  public func setDefault(applicationURL: URL) throws(XcodeRegistryError) {
    guard discovery.xcode(at: applicationURL) != nil else {
      throw XcodeRegistryError.notAnXcode(applicationURL)
    }
    store.setString(Self.key(applicationURL), Key.preferred)
  }

  /// Unpins the default so the index follows the `xcode-select` Xcode.
  public func clearDefault() {
    store.removeValue(Key.preferred)
  }

  // MARK: - Private

  private func resolveActive(
    auto: [XcodeInstallation],
    manual: [(URL, XcodeInstallation?)],
    system: XcodeInstallation?
  ) -> XcodeInstallation? {
    var known: [String: XcodeInstallation] = [:]
    for xcode in auto {
      known[Self.key(xcode.applicationURL)] = xcode
    }
    for case let (_, xcode?) in manual {
      known[Self.key(xcode.applicationURL)] = xcode
    }

    if let preferred = preferredPath() {
      if let pinned = known[Self.key(preferred)] { return pinned }
      // A pinned Xcode can live outside the scanned directories, for
      // example in ~/Applications or a subfolder.
      if let pinned = discovery.xcode(at: preferred) { return pinned }
    }
    if let system { return system }
    return known.values.max { lhs, rhs in
      lhs.version != rhs.version
        ? lhs.version < rhs.version
        : XcodeBuildNumber(lhs.build) < XcodeBuildNumber(rhs.build)
    }
  }

  private func addedPaths() -> [URL] {
    store.stringArray(Key.added).map { URL(filePath: $0) }
  }

  private func setAddedPaths(_ urls: [URL]) {
    store.setStringArray(urls.map(Self.key), Key.added)
  }

  private func preferredPath() -> URL? {
    store.string(Key.preferred).map { URL(filePath: $0) }
  }

  /// Returns the canonical path that identifies an Xcode bundle.
  ///
  /// A directory URL from a filesystem scan carries a trailing slash and a
  /// typed path does not. One canonical form makes the two compare equal.
  ///
  /// - Parameter url: The Xcode application bundle.
  /// - Returns: The canonical path for the bundle.
  public static func canonicalPath(for url: URL) -> String {
    let path = url.standardizedFileURL.path(percentEncoded: false)
    guard path.count > 1, path.hasSuffix("/") else { return path }
    return String(path.dropLast())
  }

  private static func key(_ url: URL) -> String {
    canonicalPath(for: url)
  }
}

extension XcodeRegistry: DependencyKey {
  /// The live registry over the shared suite.
  public static let liveValue = XcodeRegistry()

  /// An in-memory registry, so a test that reads the registry without injecting
  /// one cannot touch the shared settings.
  public static let testValue = XcodeRegistry(store: .inMemory())

  /// An in-memory registry, so a preview that reads the registry without
  /// injecting one cannot touch the shared settings or scan the real
  /// filesystem.
  public static let previewValue = XcodeRegistry(store: .inMemory())
}

extension DependencyValues {
  /// The shared Xcode registry both front ends read.
  public var xcodeRegistry: XcodeRegistry {
    get { self[XcodeRegistry.self] }
    set { self[XcodeRegistry.self] = newValue }
  }
}
