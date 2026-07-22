import CoreModel
import Foundation

// The type reads Xcode's own metadata files instead of hard-coded lists, so
// results stay correct across betas.
package enum SDKDiscovery {
  // The scan skips entries without a valid developer directory or
  // toolchain. The Xcodes version-manager app is one example.
  package static func installedXcodes(
    in applicationDirectories: [URL] = [URL(filePath: "/Applications")]
  ) -> [XcodeInstallation] {
    var results: [XcodeInstallation] = []
    for directory in applicationDirectories {
      let entries =
        (try? FileManager.default.contentsOfDirectory(
          at: directory,
          includingPropertiesForKeys: nil
        )) ?? []
      for entry in entries
        where entry.lastPathComponent.hasPrefix("Xcode")
        && entry.pathExtension == "app"
      {
        if let xcode = installation(at: entry) {
          results.append(xcode)
        }
      }
    }
    return results.sorted { lhs, rhs in
      lhs.version == rhs.version
        ? (!lhs.isBeta && rhs.isBeta) : lhs.version < rhs.version
    }
  }

  // Among equal versions, a beta build sorts last. This method prefers a
  // shipping release unless it is the only build of that version.
  package static func latestXcode(
    in applicationDirectories: [URL] = [URL(filePath: "/Applications")]
  ) -> XcodeInstallation? {
    installedXcodes(in: applicationDirectories).max { lhs, rhs in
      lhs.version == rhs.version
        ? (lhs.isBeta && !rhs.isBeta) : lhs.version < rhs.version
    }
  }

  // The scan excludes Simulator, DriverKit, and Mac Catalyst SDKs. It
  // ignores symlinked SDK aliases so each platform appears once.
  package static func sdks(in xcode: XcodeInstallation) -> [InstalledSDK] {
    let platformsURL = xcode.developerDirURL.appending(path: "Platforms")
    let platformDirectories =
      (try? FileManager.default.contentsOfDirectory(
        at: platformsURL,
        includingPropertiesForKeys: nil
      )) ?? []

    var results: [InstalledSDK] = []
    for platformDirectory in platformDirectories
      where platformDirectory.pathExtension == "platform"
    {
      let sdksURL = platformDirectory.appending(path: "Developer/SDKs")
      let sdkEntries =
        (try? FileManager.default.contentsOfDirectory(
          at: sdksURL,
          includingPropertiesForKeys: [.isSymbolicLinkKey]
        )) ?? []
      for sdkEntry in sdkEntries where sdkEntry.pathExtension == "sdk" {
        let isSymlink =
          (try? sdkEntry.resourceValues(forKeys: [.isSymbolicLinkKey]))?
            .isSymbolicLink
        if isSymlink == true { continue }
        if let sdk = sdk(at: sdkEntry) {
          results.append(sdk)
        }
      }
    }
    return results.sorted {
      ($0.platform, $0.version) < ($1.platform, $1.version)
    }
  }

  package static func xcode(at applicationURL: URL) -> XcodeInstallation? {
    installation(at: applicationURL)
  }

  // Reading the symlink directly keeps the lookup in-process instead of
  // running `xcode-select` as a subprocess.
  package static func systemSelectedXcode() -> XcodeInstallation? {
    let developerDirectory: String
    if let override = ProcessInfo.processInfo.environment["DEVELOPER_DIR"],
       !override.isEmpty
    {
      developerDirectory = override
    } else if let link = try? FileManager.default.destinationOfSymbolicLink(
      atPath: "/var/db/xcode_select_link"
    ) {
      developerDirectory = link
    } else {
      return nil
    }

    let developerURL = URL(filePath: developerDirectory)
    let applicationURL =
      developerURL.pathExtension == "app"
        ? developerURL
        : developerURL.deletingLastPathComponent().deletingLastPathComponent()
    guard applicationURL.pathExtension == "app" else { return nil }
    return installation(at: applicationURL)
  }

  // MARK: - Parsing

  struct XcodeVersionInfo: Decodable {
    let shortVersion: String
    let build: String

    enum CodingKeys: String, CodingKey {
      case shortVersion = "CFBundleShortVersionString"
      case build = "ProductBuildVersion"
    }
  }

  struct SDKSettingsInfo: Decodable {
    let version: String
    let canonicalName: String

    enum CodingKeys: String, CodingKey {
      case version = "Version"
      case canonicalName = "CanonicalName"
    }
  }

  static func platform(forCanonicalName canonicalName: String) -> ApplePlatform?
  {
    let name = canonicalName.lowercased()
    if name.hasPrefix("iphoneos") { return .iOS }
    if name.hasPrefix("macosx") { return .macOS }
    if name.hasPrefix("appletvos") { return .tvOS }
    if name.hasPrefix("watchos") { return .watchOS }
    if name.hasPrefix("xros") { return .visionOS }
    return nil
  }

  // MARK: - Private

  private static func installation(at applicationURL: URL) -> XcodeInstallation?
  {
    let developerDirURL = applicationURL.appending(path: "Contents/Developer")
    guard FileManager.default.fileExists(
      atPath: developerDirURL.path(percentEncoded: false)
    )
    else {
      return nil
    }

    let versionPlistURL = applicationURL.appending(
      path: "Contents/version.plist"
    )
    guard let data = try? Data(contentsOf: versionPlistURL),
          let info = try? PropertyListDecoder().decode(
            XcodeVersionInfo.self, from: data
          ),
          let version = SemanticVersion(info.shortVersion)
    else { return nil }

    let isBeta = applicationURL.lastPathComponent.lowercased().contains("beta")
    return XcodeInstallation(
      applicationURL: applicationURL,
      developerDirURL: developerDirURL,
      version: version,
      build: info.build,
      isBeta: isBeta
    )
  }

  private static func sdk(at sdkURL: URL) -> InstalledSDK? {
    let settingsURL = sdkURL.appending(path: "SDKSettings.plist")
    guard let data = try? Data(contentsOf: settingsURL),
          let info = try? PropertyListDecoder().decode(
            SDKSettingsInfo.self, from: data
          ),
          let platform = Self.platform(forCanonicalName: info.canonicalName),
          let version = SemanticVersion(info.version)
    else { return nil }

    return InstalledSDK(
      platform: platform,
      version: version,
      sdkURL: sdkURL,
      canonicalName: info.canonicalName
    )
  }
}
