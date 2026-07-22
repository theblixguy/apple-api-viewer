import CoreModel
import Dependencies
import Foundation
import os
import SDKDiscovery
import SymbolExtraction
import SymbolGraphIndex
import SymbolSource

/// A symbol source that indexes Apple's bundled SDK frameworks for one
/// Xcode installation.
///
/// Indexing only the latest Xcode's SDKs also answers queries about APIs
/// introduced in earlier releases.
public struct SDKSymbolSource: SymbolSource {
  private let xcode: XcodeInstallation
  @Dependency(\.sdkDiscovery) private var discovery
  @Dependency(\.symbolGraphExtractor) private var extractor

  private static let logger = Logger(
    subsystem: "com.suyashsrijan.apple-api-viewer", category: "SDKSymbolSource"
  )

  /// Creates a source backed by the given Xcode's installed SDKs.
  ///
  /// - Parameter xcode: The Xcode installation whose SDKs the source
  ///   indexes.
  public init(xcode: XcodeInstallation) {
    self.xcode = xcode
  }

  /// The origin this source indexes symbols from.
  public var source: Source { .appleSDK(for: xcode) }

  /// Returns the platforms whose SDKs are installed in this Xcode, in
  /// canonical display order.
  ///
  /// - Returns: The platforms with installed SDKs, in canonical display
  ///   order.
  public func installedPlatforms() -> [ApplePlatform] {
    let installed = Set(discovery.sdks(in: xcode).map(\.platform))
    return ApplePlatform.allCases.filter(installed.contains)
  }

  /// Returns a fingerprint of the toolchain and installed SDK set.
  ///
  /// A changed fingerprint marks the stored index as stale.
  ///
  /// - Returns: A fingerprint string for the toolchain and installed SDK
  ///   set.
  public func signature() -> String {
    let sdks = discovery.sdks(in: xcode)
    return xcode.build + "|"
      + sdks.map(\.canonicalName).sorted().joined(separator: ",")
  }

  /// Extracts every module across the installed SDKs, reporting progress
  /// and handing each finished framework to `consume`.
  ///
  /// A module present in several SDKs reaches `consume` once per SDK, in
  /// completion order, for the caller to merge by USR.
  ///
  /// - Parameters:
  ///   - progress: A callback that receives indexing progress updates.
  ///   - consume: A callback that receives each finished framework index.
  ///
  /// - Throws: An error when toolchain verification fails or `consume`
  ///   throws for a framework.
  public func extractFrameworks(
    progress: @escaping @Sendable (IndexingProgress) async -> Void,
    consume: @escaping @Sendable (FrameworkIndex) async throws -> Void
  ) async throws {
    try await extract(
      units: makeUnits(platforms: nil), progress: progress, consume: consume
    )
  }

  /// Returns the index for one module by name across the installed SDKs.
  ///
  /// - Parameter moduleName: The name of the module to index.
  ///
  /// - Returns: The index for the module, or `nil` if the module is in
  ///   none of the installed SDKs.
  ///
  /// - Throws: An error when extraction or parsing fails on any SDK. The
  ///   bulk build skips broken modules, but a single-module reindex reports
  ///   the failure.
  public func makeFramework(named moduleName: String) async throws
    -> FrameworkIndex?
  {
    let xcode = xcode
    let extractor = extractor
    try extractor.verifyToolchain(xcode: xcode)
    // Most frameworks are absent from at least one platform's SDK, and
    // extracting from an SDK without the module will trigger an error.
    // Without this filter, that error would fail the re-index for the
    // SDKs that do have the module.
    let sdks = discovery.sdks(in: xcode).filter {
      extractor.extractableModules(in: $0).contains(moduleName)
    }
    guard !sdks.isEmpty else { return nil }
    let workRoot = FileManager.default.temporaryDirectory
      .appending(
        path: "symbolsources-module-\(moduleName)-\(UUID().uuidString)"
      )
    try FileManager.default.createDirectory(
      at: workRoot, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: workRoot) }

    let indexes = try await withThrowingTaskGroup(of: FrameworkIndex?.self) {
      group in
      for sdk in sdks {
        group.addTask {
          try await Self.process(
            IndexUnit(sdk: sdk, module: moduleName), xcode: xcode,
            extractor: extractor, workRoot: workRoot
          )
        }
      }
      var collected: [FrameworkIndex] = []
      for try await index in group {
        try Task.checkCancellation()
        if let index { collected.append(index) }
      }
      return collected
    }
    guard !indexes.isEmpty else { return nil }
    return SymbolGraphParser.merge(indexes, moduleName: moduleName)
  }

  // MARK: - Internal

  struct IndexUnit: Sendable, Hashable {
    let sdk: InstalledSDK
    let module: String
  }

  func makeUnits(platforms: [ApplePlatform]?) -> [IndexUnit] {
    let allSDKs = discovery.sdks(in: xcode)
    let sdks =
      platforms.map { wanted in allSDKs.filter { wanted.contains($0.platform) }
      } ?? allSDKs
    let extractor = extractor
    return sdks.flatMap { sdk in
      extractor.extractableModules(in: sdk).map {
        IndexUnit(sdk: sdk, module: $0)
      }
    }
  }

  func extract(
    units: [IndexUnit],
    progress: @escaping @Sendable (IndexingProgress) async -> Void,
    consume: @escaping @Sendable (FrameworkIndex) async throws -> Void
  ) async throws {
    let xcode = xcode
    let extractor = extractor
    try extractor.verifyToolchain(xcode: xcode)
    let workRoot = FileManager.default.temporaryDirectory
      .appending(
        path: "symbolsources-index-\(xcode.build)-\(UUID().uuidString)"
      )
    try FileManager.default.createDirectory(
      at: workRoot, withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )
    defer { try? FileManager.default.removeItem(at: workRoot) }

    let total = units.count
    let parallelism = max(2, ProcessInfo.processInfo.activeProcessorCount - 1)

    try await withThrowingTaskGroup(of: UnitOutcome.self) { group in
      var scheduled = 0
      func scheduleNextUnit() {
        guard scheduled < total else { return }
        let unit = units[scheduled]
        scheduled += 1
        group.addTask {
          try await Self.processReportingFailures(
            unit, xcode: xcode, extractor: extractor, workRoot: workRoot
          )
        }
      }

      for _ in 0..<parallelism { scheduleNextUnit() }

      var completed = 0
      var consecutiveFailures = 0
      while let outcome = try await group.next() {
        try Task.checkCancellation()
        completed += 1
        scheduleNextUnit()
        var currentModule: String?
        switch outcome {
        case let .framework(index):
          consecutiveFailures = 0
          currentModule = index.moduleName
          try await consume(index)
        case .empty:
          consecutiveFailures = 0
        case .failed:
          consecutiveFailures += 1
          guard consecutiveFailures < Self.consecutiveFailureLimit else {
            throw RepeatedFailureError(failureCount: consecutiveFailures)
          }
        }
        await progress(
          IndexingProgress(
            completed: completed, total: total, currentModule: currentModule
          )
        )
      }
    }
  }

  private static func process(
    _ unit: IndexUnit,
    xcode: XcodeInstallation,
    extractor: SymbolGraphExtractorClient,
    workRoot: URL
  ) async throws -> FrameworkIndex? {
    let outputDirectory = workRoot.appending(
      path: "\(unit.sdk.platform.rawValue)-\(unit.module)"
    )
    defer { try? FileManager.default.removeItem(at: outputDirectory) }

    let files = try await extractor.extract(
      xcode: xcode, module: unit.module, sdk: unit.sdk,
      into: outputDirectory
    )
    guard !files.isEmpty else { return nil }
    let indexes = try files.map { url in
      try SymbolGraphParser.parse(
        Data(contentsOf: url), moduleNameOverride: unit.module
      )
    }
    return SymbolGraphParser.merge(indexes, moduleName: unit.module)
  }

  // A failure is distinct from a module with no output so the caller can
  // count failures.
  enum UnitOutcome: Sendable {
    case framework(FrameworkIndex)
    case empty
    case failed
  }

  // This many failures in a row indicate a systemic cause, for example a
  // full disk or a removed Xcode, not that many broken modules.
  static let consecutiveFailureLimit = 20

  // One broken module must not fail the whole build. A missing toolchain
  // fails every remaining module the same way, so that error stops the
  // build immediately.
  private static func processReportingFailures(
    _ unit: IndexUnit,
    xcode: XcodeInstallation,
    extractor: SymbolGraphExtractorClient,
    workRoot: URL
  ) async throws -> UnitOutcome {
    do {
      guard let index = try await process(
        unit, xcode: xcode, extractor: extractor, workRoot: workRoot
      )
      else { return .empty }
      return .framework(index)
    } catch {
      try Task.checkCancellation()
      if let extractionError = error as? SymbolGraphExtractor.ExtractionError,
         case .toolchainMissing = extractionError
      {
        throw error
      }
      let reason = String(describing: error)
      Self.logger.warning(
        "Skipped \(unit.module, privacy: .public): \(reason, privacy: .public)"
      )
      return .failed
    }
  }
}
