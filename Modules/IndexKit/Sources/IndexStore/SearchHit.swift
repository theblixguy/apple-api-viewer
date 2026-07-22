import SymbolGraphIndex

/// A global-search result.
public struct SearchHit: Sendable, Hashable, Identifiable {
  /// The symbol's USR.
  public let usr: String
  /// The display title of the symbol.
  public let title: String
  /// The symbol's name.
  public let name: String
  /// The symbol's kind.
  public let kind: SymbolKind
  /// The module name of the framework the symbol belongs to.
  public let moduleName: String
  /// The symbol's path components, from outermost to the symbol itself.
  public let pathComponents: [String]
  /// A stable identifier, the symbol's USR.
  public var id: String { usr }

  /// Creates a search hit from its symbol fields.
  ///
  /// - Parameters:
  ///   - usr: The symbol's USR.
  ///   - title: The display title of the symbol.
  ///   - name: The symbol's name.
  ///   - kind: The symbol's kind.
  ///   - moduleName: The module name of the framework the symbol belongs to.
  ///   - pathComponents: The symbol's path components, from outermost to the
  ///     symbol itself.
  public init(
    usr: String, title: String, name: String, kind: SymbolKind,
    moduleName: String,
    pathComponents: [String]
  ) {
    self.usr = usr
    self.title = title
    self.name = name
    self.kind = kind
    self.moduleName = moduleName
    self.pathComponents = pathComponents
  }
}
