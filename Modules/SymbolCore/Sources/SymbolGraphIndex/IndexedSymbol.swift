import CoreModel

/// One API declaration extracted from a symbol source, reduced to the fields
/// the app needs.
public struct IndexedSymbol: Sendable, Hashable, Codable, Identifiable {
  /// The unified symbol resolution identifier, or USR, stable across builds
  /// and unique within a framework. The index uses it as the node identity.
  public let usr: String

  /// The display title from the symbol graph, for example
  /// `"PKStroke.RenderState"`.
  public let title: String

  /// The kind of declaration.
  public let kind: SymbolKind

  /// The documentation path components, excluding the framework, for
  /// example `["PKStroke", "RenderState"]`.
  public let pathComponents: [String]

  /// The USR of the enclosing symbol, from a `memberOf` relationship, or
  /// `nil` for a top-level declaration.
  public let parentUSR: String?

  /// Where and when the symbol became available, as one record per
  /// availability domain. For SDK symbols this is the per-platform OS
  /// introduced versions.
  public let availability: [Availability]

  /// A Boolean value that indicates whether the symbol is deprecated on any
  /// platform.
  public let isDeprecated: Bool

  /// The symbol's documentation comment, including its abstract and
  /// discussion, if any.
  public let summary: String?

  /// A stable identifier, the symbol's USR.
  public var id: String { usr }

  /// The bare symbol name, the last path component, for example
  /// `"RenderState"`.
  public var name: String { pathComponents.last ?? title }

  /// The OS release each platform first shipped this API in.
  ///
  /// The platform-domain view of the availability records, used for the
  /// OS-version browse. The property omits domains without a version and
  /// non-platform domains.
  ///
  /// - Complexity: O(*n*), building a fresh dictionary from `availability` on
  ///   every access. Prefer ``wasIntroduced(in:)`` for a single-release check.
  public var introduced: [ApplePlatform: SemanticVersion] {
    var result: [ApplePlatform: SemanticVersion] = [:]
    for entry in availability {
      guard case let .platform(platform) = entry.domain,
            let version = entry.introduced
      else {
        continue
      }
      result[platform] = version
    }
    return result
  }

  /// Creates a symbol from its general availability records.
  ///
  /// - Parameters:
  ///   - usr: The unified symbol resolution identifier, stable across builds
  ///     and unique within a framework.
  ///   - title: The display title from the symbol graph, for example
  ///     `"PKStroke.RenderState"`.
  ///   - kind: The kind of declaration.
  ///   - pathComponents: The documentation path components, excluding the
  ///     framework.
  ///   - parentUSR: The USR of the enclosing symbol, or `nil` for a
  ///     top-level declaration.
  ///   - availability: Where and when the symbol became available, as one
  ///     record per availability domain.
  ///   - isDeprecated: A Boolean value that indicates whether the symbol is
  ///     deprecated on any platform.
  ///   - summary: The symbol's documentation comment, including its
  ///     abstract and discussion, if any.
  public init(
    usr: String,
    title: String,
    kind: SymbolKind,
    pathComponents: [String],
    parentUSR: String?,
    availability: [Availability],
    isDeprecated: Bool,
    summary: String? = nil
  ) {
    self.usr = usr
    self.title = title
    self.kind = kind
    self.pathComponents = pathComponents
    self.parentUSR = parentUSR
    self.availability = availability
    self.isDeprecated = isDeprecated
    self.summary = summary
  }

  /// Creates a symbol from SDK-style per-platform introduced versions, mapping
  /// each to a `.platform` availability record.
  ///
  /// - Parameters:
  ///   - usr: The unified symbol resolution identifier, stable across builds
  ///     and unique within a framework.
  ///   - title: The display title from the symbol graph, for example
  ///     `"PKStroke.RenderState"`.
  ///   - kind: The kind of declaration.
  ///   - pathComponents: The documentation path components, excluding the
  ///     framework.
  ///   - parentUSR: The USR of the enclosing symbol, or `nil` for a
  ///     top-level declaration.
  ///   - introduced: The OS release each platform first shipped this API in.
  ///   - isDeprecated: A Boolean value that indicates whether the symbol is
  ///     deprecated on any platform.
  ///   - summary: The symbol's documentation comment, including its
  ///     abstract and discussion, if any.
  public init(
    usr: String,
    title: String,
    kind: SymbolKind,
    pathComponents: [String],
    parentUSR: String?,
    introduced: [ApplePlatform: SemanticVersion],
    isDeprecated: Bool,
    summary: String? = nil
  ) {
    self.init(
      usr: usr,
      title: title,
      kind: kind,
      pathComponents: pathComponents,
      parentUSR: parentUSR,
      availability:
      introduced
        .sorted { $0.key.rawValue < $1.key.rawValue }
        .map { Availability(domain: .platform($0.key), introduced: $0.value) },
      isDeprecated: isDeprecated,
      summary: summary
    )
  }
}
