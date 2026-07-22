import CoreModel

/// A filter for APIs introduced in one OS release on one platform.
///
/// Selecting iOS 27.0 together with macOS 26.5 is two selections. An API
/// matches if it was introduced in *any* selected release on its platform.
public struct VersionSelection: Sendable, Hashable, Codable {
  /// The platform the release belongs to.
  public let platform: ApplePlatform
  /// The selected OS release.
  public let version: SemanticVersion

  /// Creates a selection from a platform and one of its OS releases.
  ///
  /// - Parameters:
  ///   - platform: The platform the release belongs to.
  ///   - version: The selected OS release.
  public init(platform: ApplePlatform, version: SemanticVersion) {
    self.platform = platform
    self.version = version
  }
}

extension IndexedSymbol {
  /// Returns whether the symbol was introduced in exactly the selected OS
  /// release on that platform.
  ///
  /// - Parameter selection: The platform and OS release to match against.
  /// - Returns: `true` if the symbol was introduced in the selected release
  ///   on that platform; otherwise, `false`.
  public func wasIntroduced(in selection: VersionSelection) -> Bool {
    availability.contains { entry in
      entry.domain == .platform(selection.platform)
        && entry.introduced?.isSameRelease(as: selection.version) == true
    }
  }

  /// Returns whether the symbol was introduced in any of the selected
  /// releases.
  ///
  /// - Parameter selections: The platform-and-release pairs to match
  ///   against.
  /// - Returns: `true` if the symbol was introduced in any selected release;
  ///   otherwise, `false`.
  public func wasIntroduced(inAnyOf selections: [VersionSelection]) -> Bool {
    selections.contains { wasIntroduced(in: $0) }
  }
}

extension FrameworkIndex {
  func newSymbols(for selections: [VersionSelection]) -> [IndexedSymbol] {
    guard !selections.isEmpty else { return [] }
    return symbols.filter { $0.wasIntroduced(inAnyOf: selections) }
  }
}
