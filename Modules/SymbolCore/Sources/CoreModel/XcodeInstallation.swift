import Foundation

/// An installed Xcode, including beta releases, and the toolchain it
/// provides.
public struct XcodeInstallation: Sendable, Hashable, Identifiable {
  /// The application bundle, for example `/Applications/Xcode-beta.app`.
  public let applicationURL: URL
  /// The `Contents/Developer` directory, the path that `xcode-select -p`
  /// prints.
  public let developerDirURL: URL
  /// The Xcode version.
  public let version: SemanticVersion
  /// The product build, for example `27A5194q`.
  public let build: String
  /// A Boolean value that indicates whether this is a beta release.
  public let isBeta: Bool

  /// A stable identifier, the application bundle URL.
  public var id: URL { applicationURL }

  /// The `swift` driver in this Xcode's default toolchain, used to run
  /// `symbolgraph-extract`.
  public var toolchainSwiftURL: URL {
    developerDirURL.appending(
      path: "Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
    )
  }

  /// Creates an Xcode installation from its bundle, toolchain, and version.
  ///
  /// - Parameters:
  ///   - applicationURL: The application bundle, for example
  ///     `/Applications/Xcode-beta.app`.
  ///   - developerDirURL: The `Contents/Developer` directory, the path that
  ///     `xcode-select -p` prints.
  ///   - version: The Xcode version.
  ///   - build: The product build, for example `27A5194q`.
  ///   - isBeta: A Boolean value that indicates whether this is a beta
  ///     release.
  public init(
    applicationURL: URL,
    developerDirURL: URL,
    version: SemanticVersion,
    build: String,
    isBeta: Bool
  ) {
    self.applicationURL = applicationURL
    self.developerDirURL = developerDirURL
    self.version = version
    self.build = build
    self.isBeta = isBeta
  }

  /// A label such as `Xcode 27.0 beta (27A5194q)`.
  public var displayName: String {
    "Xcode \(version)\(isBeta ? " beta" : "") (\(build))"
  }
}
