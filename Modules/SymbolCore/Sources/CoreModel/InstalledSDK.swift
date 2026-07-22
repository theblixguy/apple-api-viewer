import Foundation

/// A platform SDK inside an Xcode, for example iPhoneOS 27.0. This is the
/// unit that a symbol graph is extracted against.
public struct InstalledSDK: Sendable, Hashable, Identifiable {
  /// The platform the SDK targets.
  public let platform: ApplePlatform
  /// The SDK version.
  public let version: SemanticVersion
  /// The `.sdk` directory.
  public let sdkURL: URL
  /// The canonical SDK name, for example `iphoneos27.0`.
  public let canonicalName: String

  /// A stable identifier, the canonical SDK name.
  public var id: String { canonicalName }

  /// The bundled system frameworks directory, passed to `symbolgraph-extract`
  /// via `-F`.
  public var frameworksURL: URL {
    sdkURL.appending(path: "System/Library/Frameworks")
  }

  /// Creates an installed SDK from its platform, version, and location.
  ///
  /// - Parameters:
  ///   - platform: The platform the SDK targets.
  ///   - version: The SDK version.
  ///   - sdkURL: The `.sdk` directory.
  ///   - canonicalName: The canonical SDK name, for example `iphoneos27.0`.
  public init(
    platform: ApplePlatform, version: SemanticVersion, sdkURL: URL,
    canonicalName: String
  ) {
    self.platform = platform
    self.version = version
    self.sdkURL = sdkURL
    self.canonicalName = canonicalName
  }

  /// Returns the LLVM target triple for `symbolgraph-extract`, for example
  /// `arm64-apple-ios27.0`.
  ///
  /// - Parameter architecture: The target architecture. The default is
  ///   `arm64`, which every extracted SDK supports. Pass a different value,
  ///   such as `x86_64`, to target another architecture.
  /// - Returns: The target triple, for example `arm64-apple-ios27.0`.
  public func targetTriple(architecture: String = "arm64") -> String {
    "\(architecture)-apple-\(platform.targetTripleOS)\(version.major).\(version.minor)"
  }
}
