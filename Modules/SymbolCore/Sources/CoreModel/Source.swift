/// How a source reads its symbols, which determines their fidelity.
///
/// This describes the access method, not the origin. The ``Source`` type
/// carries the origin, such as the SDK, package, or binary. A
/// ``privateSymbols`` scan applies equally to an Apple SDK dylib or to a
/// third-party closed binary. Both are the same kind, with a different
/// ``Source``.
///
/// Only ``appleSDK`` has a producer. The other cases are reserved for future
/// extractors.
public enum SourceKind: String, Sendable, Hashable, Codable, CaseIterable {
  /// Apple SDK public API, via `swift symbolgraph-extract`. It carries symbol
  /// kinds, documentation, and per-platform `@available` introduced versions.
  case appleSDK

  /// A third-party Swift package's public API, via `swift build
  /// --emit-symbol-graph`. Versions are package releases. Reserved for a
  /// future producer.
  case swiftPackage

  /// A symbol-table scan, using `nm` or `otool`, of a binary that has no
  /// public headers or source. Examples are an Apple SDK dylib or a
  /// third-party closed binary. This produces names only, with no
  /// availability versions. ``Availability/introduced`` is `nil` for such a
  /// symbol. Reserved for a future producer.
  case privateSymbols
}

/// Where a source's symbols come from, pairing an origin with an access
/// method.
///
/// Every indexed framework belongs to exactly one source. This lets the
/// index show where an API came from.
public struct Source: Sendable, Hashable, Identifiable, Codable {
  /// A stable identifier for the origin, unique across configured sources,
  /// for example `"apple-sdk"`.
  public let id: String
  /// How the source reads its symbols.
  public let kind: SourceKind
  /// A user-facing name for the source, for example `"Apple SDKs"`.
  public let displayName: String

  /// Creates a source from its origin identifier, access method, and name.
  ///
  /// - Parameters:
  ///   - id: A stable identifier for the origin, unique across configured
  ///     sources, for example `"apple-sdk"`.
  ///   - kind: How the source reads its symbols.
  ///   - displayName: A user-facing name for the source, for example
  ///     `"Apple SDKs"`.
  public init(id: String, kind: SourceKind, displayName: String) {
    self.id = id
    self.kind = kind
    self.displayName = displayName
  }
}

extension Source {
  /// Returns the source for one Xcode's bundled SDK frameworks.
  ///
  /// Each Xcode build gets its own source. Several Xcodes' indexes can
  /// coexist in the store, and switching between them never rebuilds the
  /// others. Its symbols carry per-platform OS availability.
  ///
  /// - Parameter xcode: The Xcode installation to build a source for.
  /// - Returns: The source for the Xcode's bundled SDK frameworks.
  public static func appleSDK(for xcode: XcodeInstallation) -> Source {
    Source(
      id: appleSDKID(forBuild: xcode.build), kind: .appleSDK,
      displayName: xcode.displayName
    )
  }

  /// Returns the source identifier for an Xcode's SDK index, from its
  /// product build.
  ///
  /// - Parameter build: The Xcode product build, for example `27A5194q`.
  /// - Returns: The source identifier for the Xcode's SDK index.
  public static func appleSDKID(forBuild build: String) -> ID {
    "apple-sdk:\(build)"
  }
}
