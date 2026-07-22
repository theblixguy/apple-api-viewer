import CoreModel
import Dependencies
import Foundation

/// An injectable interface to Xcode and SDK discovery.
///
/// A test can substitute a client that returns fixed values instead of
/// scanning the filesystem.
public struct SDKDiscoveryClient: Sendable {
  private let _installedXcodes: @Sendable ([URL]) -> [XcodeInstallation]
  private let _sdks: @Sendable (XcodeInstallation) -> [InstalledSDK]
  private let _xcodeAt: @Sendable (URL) -> XcodeInstallation?
  private let _systemSelectedXcode: @Sendable () -> XcodeInstallation?

  /// Creates a client from its endpoints.
  ///
  /// - Parameters:
  ///   - installedXcodes: The endpoint that lists Xcode installations under
  ///     a set of application directories.
  ///   - sdks: The endpoint that lists the device SDKs installed in an
  ///     Xcode.
  ///   - xcodeAt: The endpoint that resolves the Xcode at an application
  ///     bundle URL.
  ///   - systemSelectedXcode: The endpoint that resolves the Xcode that
  ///     `xcode-select` points at.
  public init(
    installedXcodes: @escaping @Sendable ([URL]) -> [XcodeInstallation],
    sdks: @escaping @Sendable (XcodeInstallation) -> [InstalledSDK],
    xcodeAt: @escaping @Sendable (URL) -> XcodeInstallation?,
    systemSelectedXcode: @escaping @Sendable () -> XcodeInstallation?
  ) {
    _installedXcodes = installedXcodes
    _sdks = sdks
    _xcodeAt = xcodeAt
    _systemSelectedXcode = systemSelectedXcode
  }

  /// Returns the Xcode installations found under the given application
  /// directories.
  ///
  /// - Parameter applicationDirectories: The directories to search for
  ///   Xcode installations.
  ///
  /// - Returns: The Xcode installations found under the given directories.
  public func installedXcodes(
    in applicationDirectories: [URL] = [URL(filePath: "/Applications")]
  ) -> [XcodeInstallation] {
    _installedXcodes(applicationDirectories)
  }

  /// Returns the device SDKs in an Xcode, one per platform.
  ///
  /// - Parameter xcode: The Xcode installation to search for SDKs.
  ///
  /// - Returns: The device SDKs installed in the Xcode, one per platform.
  public func sdks(in xcode: XcodeInstallation) -> [InstalledSDK] {
    _sdks(xcode)
  }

  /// Returns the Xcode at the given application bundle.
  ///
  /// - Parameter applicationURL: The application bundle to resolve.
  ///
  /// - Returns: The Xcode at the application bundle, or `nil` if it is
  ///   missing or not a usable Xcode.
  public func xcode(at applicationURL: URL) -> XcodeInstallation? {
    _xcodeAt(applicationURL)
  }

  /// Returns the Xcode that `xcode-select` points at.
  ///
  /// - Returns: The system-selected Xcode, or `nil` if it cannot be
  ///   resolved.
  public func systemSelectedXcode() -> XcodeInstallation? {
    _systemSelectedXcode()
  }
}

extension SDKDiscoveryClient: DependencyKey {
  /// The live client, backed by the real filesystem scan.
  public static let liveValue = SDKDiscoveryClient(
    installedXcodes: { SDKDiscovery.installedXcodes(in: $0) },
    sdks: { SDKDiscovery.sdks(in: $0) },
    xcodeAt: { SDKDiscovery.xcode(at: $0) },
    systemSelectedXcode: { SDKDiscovery.systemSelectedXcode() }
  )

  /// The default value used in tests.
  ///
  /// It defaults to the live scan, so an integration test sees the real
  /// Xcodes unless it overrides the client.
  public static let testValue = liveValue
}

extension DependencyValues {
  /// The client for Xcode and SDK discovery.
  public var sdkDiscovery: SDKDiscoveryClient {
    get { self[SDKDiscoveryClient.self] }
    set { self[SDKDiscoveryClient.self] = newValue }
  }
}
