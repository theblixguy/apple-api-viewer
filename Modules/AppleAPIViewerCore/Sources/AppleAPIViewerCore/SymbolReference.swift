/// Identifies a symbol together with the framework it lives in.
///
/// Carrying the module resolves the symbol whether it was chosen from
/// the tree or from search results.
public struct SymbolReference: Hashable, Sendable {
  /// The unified symbol resolution (USR) identifier of the referenced symbol.
  public let usr: String
  /// The framework (module) the symbol lives in.
  public let moduleName: String

  /// Creates a reference to the symbol with the given USR and module.
  ///
  /// - Parameters:
  ///   - usr: The unified symbol resolution (USR) identifier of the
  ///     referenced symbol.
  ///   - moduleName: The framework (module) the symbol lives in.
  public init(usr: String, moduleName: String) {
    self.usr = usr
    self.moduleName = moduleName
  }
}
