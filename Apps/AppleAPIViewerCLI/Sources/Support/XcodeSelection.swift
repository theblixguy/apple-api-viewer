import CoreModel
import Dependencies
import IndexOrchestration

// With no build number, every index command falls back to the registry's
// active Xcode. Each command then honors the pinned default and the
// `xcode-select` fallback.
func selectedXcode(build: String?) async -> XcodeInstallation? {
  @Dependency(\.xcodeRegistry) var registry
  guard let build else { return await registry.activeXcode() }
  return await registry.entries().compactMap(\.installation).first {
    $0.build == build
  }
}

// A wrong build number and a machine with no Xcode are different
// problems, so scripts get different exit codes for them.
func requireSelectedXcode(
  build: String?, format: OutputFormat
) async throws -> XcodeInstallation {
  if let xcode = await selectedXcode(build: build) {
    return xcode
  }
  if let build {
    throw fail(
      "No managed Xcode has build \(build). Run 'apple-api-viewer-cli xcode list' to see the managed Xcodes.",
      code: ExitStatus.notFound, name: "notFound", format: format
    )
  }
  throw fail(
    "No Xcode found in /Applications. Install Xcode, or add one with 'apple-api-viewer-cli xcode add <path>'.",
    code: ExitStatus.noXcode, name: "noXcode", format: format
  )
}
