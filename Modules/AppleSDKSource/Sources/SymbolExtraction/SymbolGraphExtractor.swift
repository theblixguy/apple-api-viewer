import CoreModel
import Foundation
import Subprocess
import System

package enum SymbolGraphExtractor {
  package enum ExtractionError: Error, LocalizedError, Sendable {
    case toolchainMissing(URL)
    case processFailed(module: String, status: Int32, standardError: String)

    package var errorDescription: String? {
      switch self {
      case let .toolchainMissing(url):
        return
          "The Swift toolchain wasn't found at \(url.path(percentEncoded: false))."
      case let .processFailed(module, status, standardError):
        let detail = standardError.trimmingCharacters(
          in: .whitespacesAndNewlines
        )
        return detail.isEmpty
          ? "Couldn't extract \(module) (exit code \(status))."
          : "Couldn't extract \(module) (exit code \(status)): \(detail)"
      }
    }
  }

  private static let standardErrorByteLimit = 256 * 1024

  // Callers that extract a whole SDK call this method once before they
  // schedule work. A missing toolchain then fails once, immediately, not
  // as hundreds of per-module failures.
  package static func verifyToolchain(
    xcode: XcodeInstallation
  ) throws(ExtractionError) {
    guard FileManager.default.fileExists(
      atPath: xcode.toolchainSwiftURL.path(percentEncoded: false)
    )
    else {
      throw ExtractionError.toolchainMissing(xcode.toolchainSwiftURL)
    }
  }

  package static func extract(
    xcode: XcodeInstallation,
    module: String,
    sdk: InstalledSDK,
    into outputDirectory: URL,
    minimumAccessLevel: SymbolGraphAccessLevel = .public
  ) async throws -> [URL] {
    try verifyToolchain(xcode: xcode)
    try FileManager.default.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )

    let arguments = [
      "symbolgraph-extract",
      "-module-name", module,
      "-target", sdk.targetTriple(),
      "-sdk", sdk.sdkURL.path(percentEncoded: false),
      "-F", sdk.frameworksURL.path(percentEncoded: false),
      "-output-dir", outputDirectory.path(percentEncoded: false),
      "-minimum-access-level", minimumAccessLevel.rawValue,
      // This flag shrinks large graphs by an order of magnitude. The
      // parser uses the `::SYNTHESIZED::` USR marker to drop any
      // synthesized member that still slips through.
      "-skip-synthesized-members",
      "-skip-inherited-docs",
    ]

    // swift-subprocess drains the child's pipes concurrently, so a module
    // that floods stderr cannot deadlock it. It also ties the child's
    // lifetime to this task, so a canceled index build terminates
    // in-flight extractions promptly. This call writes graphs to files, so
    // it discards stdout and captures only stderr.
    let result = try await run(
      .path(FilePath(xcode.toolchainSwiftURL.path(percentEncoded: false))),
      arguments: Arguments(arguments),
      output: .discarded,
      error: .string(limit: standardErrorByteLimit)
    )
    guard result.terminationStatus.isSuccess else {
      throw ExtractionError.processFailed(
        module: module,
        status: exitCode(of: result.terminationStatus),
        standardError: result.standardError
      )
    }
    return producedFiles(forModule: module, in: outputDirectory)
  }

  // The function excludes cross-import overlays, which have a leading
  // underscore, because the extractor emits them automatically alongside
  // their primary module.
  package static func extractableModules(in sdk: InstalledSDK) -> [String] {
    var modules = Set<String>()

    let frameworkEntries =
      (try? FileManager.default.contentsOfDirectory(
        at: sdk.frameworksURL,
        includingPropertiesForKeys: nil
      )) ?? []
    for entry in frameworkEntries where entry.pathExtension == "framework" {
      let name = entry.deletingPathExtension().lastPathComponent
      guard isValidModuleName(name),
            !isCrossImportOverlay(moduleName: name)
      else {
        continue
      }
      guard hasModuleContent(at: entry) else { continue }
      modules.insert(name)
    }

    let swiftLibURL = sdk.sdkURL.appending(path: "usr/lib/swift")
    let swiftLibEntries =
      (try? FileManager.default.contentsOfDirectory(
        at: swiftLibURL,
        includingPropertiesForKeys: nil
      )) ?? []
    for entry in swiftLibEntries where entry.pathExtension == "swiftmodule" {
      let name = entry.deletingPathExtension().lastPathComponent
      guard isValidModuleName(name),
            !isCrossImportOverlay(moduleName: name)
      else {
        continue
      }
      modules.insert(name)
    }

    return modules.sorted()
  }

  // MARK: - Helpers

  // Names come from SDK directory listings and reach the extractor as
  // argument values. Without the plain-identifier check, a maliciously
  // named bundle could be read as an option. A bundle named `-flag` is
  // one example.
  static func isValidModuleName(_ name: String) -> Bool {
    guard let first = name.first, first.isLetter || first == "_" else {
      return false
    }
    return name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }

  static func isCrossImportOverlay(moduleName: String) -> Bool {
    moduleName.hasPrefix("_")
  }

  static func producedFiles(forModule module: String, in directory: URL)
    -> [URL]
  {
    let entries =
      (try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
      )) ?? []
    return producedFiles(forModule: module, among: entries)
  }

  static func producedFiles(forModule module: String, among entries: [URL])
    -> [URL]
  {
    let primary = "\(module).symbols.json"
    let extensionPrefix = "\(module)@"
    // A cross-import overlay emits a file named
    // `<_Overlay>@<module>.symbols.json`. For example, it emits
    // `_CoreSpotlight_FoundationModels@CoreSpotlight`. The filter matches
    // that suffix too. Without it, every symbol the overlay bridges in
    // would silently vanish.
    let crossImportSuffix = "@\(module).symbols.json"
    return entries.filter { url in
      let name = url.lastPathComponent
      guard name.hasSuffix(".symbols.json") else { return false }
      return name == primary
        || name.hasPrefix(extensionPrefix)
        || name.hasSuffix(crossImportSuffix)
    }.sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  // MARK: - Private

  private static func hasModuleContent(at frameworkURL: URL) -> Bool {
    let modules = frameworkURL.appending(path: "Modules")
    let headers = frameworkURL.appending(path: "Headers")
    return FileManager.default.fileExists(
      atPath: modules.path(percentEncoded: false)
    )
      || FileManager.default.fileExists(
        atPath: headers.path(percentEncoded: false)
      )
  }

  private static func exitCode(of status: TerminationStatus) -> Int32 {
    switch status {
    case let .exited(code): Int32(code)
    case let .signaled(signal): -Int32(signal)
    }
  }
}
