import Foundation

/// Builds `developer.apple.com` documentation URLs for a symbol.
///
/// Inputs are the framework name and the symbol's path components. These
/// already exclude the framework. Apple's slugs lowercase the identifier
/// names and join them with `/`:
///
/// ```
/// PencilKit + ["PKStroke", "RenderState"]
///   produces developer.apple.com/documentation/pencilkit/pkstroke/renderstate
/// ```
///
/// - Important: Overloaded symbols, such as methods and initializers that
///   share a path but differ in signature, get a trailing `-<hash>` from
///   Apple that this type cannot derive offline. For those, this type's
///   functions produce the base path, which resolves to the symbol or to a
///   disambiguation page. ``renderJSONURL(framework:pathComponents:)`` backs
///   online resolution of the exact URL.
public enum DocumentationURLMapper {
  private static let host = "developer.apple.com"

  /// Returns the canonical documentation web page for a symbol.
  ///
  /// - Parameters:
  ///   - framework: The framework name, used as the first path segment.
  ///   - pathComponents: The symbol's documentation path components,
  ///     excluding the framework name.
  /// - Returns: The best-effort documentation page URL.
  public static func documentationURL(
    framework: String, pathComponents: [String]
  ) -> URL {
    url(pathSegments: ["documentation"] + slugged(framework, pathComponents))
  }

  /// Returns the Apple render-JSON endpoint backing the documentation web
  /// page.
  ///
  /// The documentation site is a single-page app that loads these JSON
  /// files. Fetching one confirms that a constructed URL resolves. It also
  /// gives canonical metadata, including the disambiguated URL for
  /// overloads.
  ///
  /// - Parameters:
  ///   - framework: The framework name, used as the first path segment.
  ///   - pathComponents: The symbol's documentation path components,
  ///     excluding the framework name.
  /// - Returns: The render JSON URL for the symbol's documentation page.
  public static func renderJSONURL(framework: String, pathComponents: [String])
    -> URL
  {
    var segments =
      ["tutorials", "data", "documentation"]
        + slugged(framework, pathComponents)
    segments[segments.count - 1] += ".json"
    return url(pathSegments: segments)
  }

  // MARK: - Private

  private static func slugged(_ framework: String, _ pathComponents: [String])
    -> [String]
  {
    ([framework] + pathComponents).map { $0.lowercased() }
  }

  private static func url(pathSegments: [String]) -> URL {
    var components = URLComponents()
    components.scheme = "https"
    components.host = Self.host
    components.percentEncodedPath =
      "/" + pathSegments.map(encodedSegment).joined(separator: "/")
    return components.url ?? Self.siteRoot
  }

  // An operator name can contain `/`, as in `/(_:_:)`. Without percent
  // encoding, that character would split the segment in two.
  private static func encodedSegment(_ segment: String) -> String {
    segment.addingPercentEncoding(withAllowedCharacters: segmentAllowed)
      ?? segment
  }

  private static let segmentAllowed: CharacterSet = {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "/")
    return allowed
  }()

  private static let siteRoot: URL = {
    guard let url = URL(string: "https://\(host)") else {
      preconditionFailure("\(host) must form a valid URL.")
    }
    return url
  }()
}
