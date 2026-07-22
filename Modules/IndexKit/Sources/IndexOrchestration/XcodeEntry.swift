import CoreModel
import Foundation

/// One Xcode in the managed registry, whether it currently resolves or not.
public struct XcodeEntry: Sendable, Hashable, Identifiable {
  /// The Xcode application bundle, the entry's stable identity.
  public let applicationURL: URL

  /// The resolved Xcode, or `nil` when the bundle is missing or unusable.
  public let installation: XcodeInstallation?

  /// A Boolean value that indicates whether the user added this entry by
  /// hand instead of through automatic detection.
  public let isManuallyAdded: Bool

  /// A Boolean value that indicates whether the index builds from this
  /// Xcode.
  public let isDefault: Bool

  /// A Boolean value that indicates whether `xcode-select` currently points
  /// at this Xcode.
  public let isSystemSelected: Bool

  /// The application bundle, reused as the identity.
  public var id: URL { applicationURL }

  /// A Boolean value that indicates whether the bundle no longer resolves to
  /// a usable Xcode.
  public var isBroken: Bool { installation == nil }

  /// Creates a registry entry.
  ///
  /// - Parameters:
  ///   - applicationURL: The Xcode application bundle.
  ///   - installation: The resolved Xcode, or `nil` when it is broken.
  ///   - isManuallyAdded: Whether the user added the entry by hand.
  ///   - isDefault: Whether the index builds from this Xcode.
  ///   - isSystemSelected: Whether `xcode-select` points at it.
  public init(
    applicationURL: URL,
    installation: XcodeInstallation?,
    isManuallyAdded: Bool,
    isDefault: Bool,
    isSystemSelected: Bool
  ) {
    self.applicationURL = applicationURL
    self.installation = installation
    self.isManuallyAdded = isManuallyAdded
    self.isDefault = isDefault
    self.isSystemSelected = isSystemSelected
  }
}

extension XcodeEntry: Comparable {
  /// Returns a Boolean value that indicates whether `lhs` sorts before `rhs`.
  ///
  /// Valid Xcodes sort before broken ones, newer versions sort first, and
  /// ties break by build then bundle path.
  ///
  /// - Parameters:
  ///   - lhs: The first entry to compare.
  ///   - rhs: The second entry to compare.
  /// - Returns: `true` when `lhs` sorts before `rhs`.
  public static func < (lhs: XcodeEntry, rhs: XcodeEntry) -> Bool {
    switch (lhs.installation, rhs.installation) {
    case let (left?, right?):
      if left.version != right.version { return left.version > right.version }
      if left.build != right.build {
        return XcodeBuildNumber(left.build) > XcodeBuildNumber(right.build)
      }
      return lhs.sortKey < rhs.sortKey
    case (.some, nil): return true
    case (nil, .some): return false
    case (nil, nil): return lhs.sortKey < rhs.sortKey
    }
  }

  private var sortKey: String {
    applicationURL.standardizedFileURL.path(percentEncoded: false)
  }
}
