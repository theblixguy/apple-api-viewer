import Foundation

/// A three-component version, `major.minor.patch`, describing an OS release
/// or the version in which an API was introduced.
///
/// Apple OS releases use `major.minor` granularity, for example iOS `27.0`
/// or macOS `26.5`. The version keeps the patch component for the rare API
/// introduced at a patch release, and for display.
public struct SemanticVersion: Sendable, Hashable, Codable, Comparable,
  CustomStringConvertible
{
  /// The major version component.
  public var major: Int
  /// The minor version component.
  public var minor: Int
  /// The patch version component.
  public var patch: Int

  /// Creates a semantic version from its components.
  ///
  /// - Parameters:
  ///   - major: The major version component.
  ///   - minor: The minor version component.
  ///   - patch: The patch version component.
  public init(major: Int, minor: Int = 0, patch: Int = 0) {
    self.major = major
    self.minor = minor
    self.patch = patch
  }

  /// The major component Apple uses as a sentinel for an API with no assigned
  /// introduced version.
  public static let unversionedMajor = 9999

  /// A Boolean value that indicates whether this is the `9999` sentinel for
  /// no assigned version.
  ///
  /// Callers should special-case this value instead of showing the raw
  /// `9999.0`.
  public var isUnversioned: Bool { major == Self.unversionedMajor }

  /// Parses a dotted version string such as `"27"`, `"27.0"` or `"16.4.1"`.
  ///
  /// - Parameter string: The dotted version string to parse.
  public init?(_ string: String) {
    let trimmed = string.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
    guard (1...3).contains(parts.count) else { return nil }

    var values = [0, 0, 0]
    for (offset, part) in parts.enumerated() {
      guard let value = Int(part), value >= 0 else { return nil }
      values[offset] = value
    }
    self.init(major: values[0], minor: values[1], patch: values[2])
  }

  /// Returns whether `lhs` orders before `rhs` by major, then minor, then
  /// patch.
  ///
  /// - Parameters:
  ///   - lhs: A version to compare.
  ///   - rhs: Another version to compare.
  /// - Returns: `true` if `lhs` orders before `rhs`; otherwise, `false`.
  public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
    (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
  }

  /// Returns whether the two versions belong to the same OS release,
  /// ignoring patch.
  ///
  /// - Parameter other: The version to compare against.
  /// - Returns: `true` if the two versions share a major and minor
  ///   component; otherwise, `false`.
  public func isSameRelease(as other: SemanticVersion) -> Bool {
    major == other.major && minor == other.minor
  }

  /// The dotted version string, omitting a zero patch.
  public var description: String {
    patch == 0 ? "\(major).\(minor)" : "\(major).\(minor).\(patch)"
  }
}
