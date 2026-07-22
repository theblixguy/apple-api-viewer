import CoreModel
import Foundation

// A scanned installation carries a directory URL with a trailing slash,
// like the ones `contentsOfDirectory` returns.
func xcodeInstallation(
  _ name: String,
  _ version: Int = 27,
  build: String = "1A",
  isBeta: Bool? = nil,
  scanned: Bool = false
) -> XcodeInstallation {
  let app = URL(
    filePath: "/Applications/\(name).app",
    directoryHint: scanned ? .isDirectory : .inferFromPath
  )
  return XcodeInstallation(
    applicationURL: app,
    developerDirURL: app.appending(path: "Contents/Developer"),
    version: SemanticVersion(major: version),
    build: build,
    isBeta: isBeta ?? name.lowercased().contains("beta")
  )
}
