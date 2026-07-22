import CoreModel
import Foundation
import IndexStore
import SymbolGraphIndex

extension BrowserModel {
  static func makeSelections(
    from chosenReleases: [ApplePlatform: Set<SemanticVersion>]
  ) -> [VersionSelection] {
    var result: [VersionSelection] = []
    for (platform, versions) in chosenReleases {
      for version in versions {
        result.append(VersionSelection(platform: platform, version: version))
      }
    }
    result.sort { lhs, rhs in
      if lhs.platform == rhs.platform { return lhs.version > rhs.version }
      return lhs.platform < rhs.platform
    }
    return result
  }

  /// Platforms with at least one selected release, in canonical order.
  public var selectedPlatforms: [ApplePlatform] {
    supportedPlatforms.filter { !(chosenReleases[$0]?.isEmpty ?? true) }
  }

  /// Returns the selected releases for a platform, newest first.
  ///
  /// - Parameter platform: The platform to return releases for.
  /// - Returns: The platform's selected releases, newest first.
  public func versions(for platform: ApplePlatform) -> [SemanticVersion] {
    (chosenReleases[platform] ?? []).sorted(by: >)
  }

  /// Returns the active filters for a platform as `VersionSelection`s.
  ///
  /// - Parameter platform: The platform to return filters for.
  /// - Returns: The active filters for the platform.
  public func selections(for platform: ApplePlatform) -> [VersionSelection] {
    versions(for: platform).map {
      VersionSelection(platform: platform, version: $0)
    }
  }

  /// Returns all selected releases for a platform spelled out, for example
  /// "26.0, 27.0".
  ///
  /// Never collapses to a count, unlike `selectionLabel(for:)`.
  ///
  /// - Parameter platform: The platform to return the label for.
  /// - Returns: The spelled-out selected releases.
  public func versionsLabel(for platform: ApplePlatform) -> String {
    Self.joinedVersionLabels(versions(for: platform))
  }

  private static func joinedVersionLabels(_ versions: [SemanticVersion])
    -> String
  {
    versions.map(versionLabel).joined(separator: ", ")
  }

  /// Returns a Boolean value that indicates whether `version` is in
  /// `platform`'s current selection.
  ///
  /// - Parameters:
  ///   - platform: The platform to check.
  ///   - version: The release to check for.
  /// - Returns: `true` when the version is in the platform's current
  ///   selection.
  public func isSelected(_ platform: ApplePlatform, _ version: SemanticVersion)
    -> Bool
  {
    chosenReleases[platform]?.contains(version) ?? false
  }

  /// Adds or removes a version from a platform's selection.
  ///
  /// - Parameters:
  ///   - platform: The platform whose selection changes.
  ///   - version: The release to add or remove.
  public func toggle(_ platform: ApplePlatform, _ version: SemanticVersion) {
    var versions = chosenReleases[platform] ?? []
    if versions.contains(version) {
      versions.remove(version)
    } else {
      versions.insert(version)
    }
    chosenReleases[platform] = versions.isEmpty ? nil : versions
  }

  /// Clears every selected release for a platform.
  ///
  /// - Parameter platform: The platform to clear.
  public func clearSelection(for platform: ApplePlatform) {
    chosenReleases[platform] = nil
  }

  /// Returns a compact label for a platform's current selection, for example
  /// "26.0, 27.0". A long selection collapses to a count instead.
  ///
  /// - Parameter platform: The platform to return the label for.
  /// - Returns: The compact selection label.
  public func selectionLabel(for platform: ApplePlatform) -> String {
    guard let versions = chosenReleases[platform], !versions.isEmpty else {
      return String(localized: "Off")
    }
    let sorted = versions.sorted(by: >)
    if sorted.count > Self.maximumInlineVersionLabels {
      return String(localized: "\(sorted.count) versions")
    }
    return Self.joinedVersionLabels(sorted)
  }

  /// Returns the display string for a version, showing the unversioned
  /// sentinel as "Unversioned" rather than the raw `9999.0`.
  ///
  /// - Parameter version: The version to return the display string for.
  /// - Returns: The version's display string.
  public nonisolated static func versionLabel(_ version: SemanticVersion)
    -> String
  {
    version.isUnversioned
      ? String(localized: "Unversioned") : version.description
  }
}
