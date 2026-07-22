/// The domain an availability version belongs to.
///
/// For a platform, the version is the OS release that introduced the symbol.
/// For a package, it is a package release.
public enum AvailabilityDomain: Sendable, Hashable, Codable {
  /// An Apple OS release line, such as iOS or macOS, used as the domain for
  /// SDK symbols.
  case platform(ApplePlatform)
  // No source produces this case yet. It is reserved for the Swift-package
  // source.
  /// A third-party package or library, identified by name.
  case package(String)
}

/// Where and when an API became available.
///
/// For an SDK symbol, this is one record per platform. For example,
/// `.platform(.iOS)` introduces version `27.0`. A `nil` introduced version
/// means the source records the symbol's presence without a version. This
/// happens for a private symbol that a source discovers in a binary. The
/// symbol then appears in the index but matches no version filter.
public struct Availability: Sendable, Hashable, Codable {
  /// The domain the version is measured against.
  public let domain: AvailabilityDomain
  /// The version the API was introduced in, or `nil` when unknown.
  public let introduced: SemanticVersion?

  /// Creates an availability record from a domain and introduced version.
  ///
  /// - Parameters:
  ///   - domain: The domain the version is measured against.
  ///   - introduced: The version the API was introduced in, or `nil` when
  ///     unknown.
  public init(domain: AvailabilityDomain, introduced: SemanticVersion?) {
    self.domain = domain
    self.introduced = introduced
  }
}
