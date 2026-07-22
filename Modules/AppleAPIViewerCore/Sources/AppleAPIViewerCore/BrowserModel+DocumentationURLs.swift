import DocURLMapping
import Foundation
import SymbolGraphIndex

extension BrowserModel {
  /// Returns the developer.apple.com documentation URL for a resolved
  /// symbol.
  ///
  /// - Parameters:
  ///   - symbol: The resolved symbol to return the URL for.
  ///   - moduleName: The framework the symbol lives in.
  /// - Returns: The documentation URL for the symbol.
  public func documentationURL(for symbol: IndexedSymbol, in moduleName: String)
    -> URL
  {
    DocumentationURLMapper.documentationURL(
      framework: moduleName, pathComponents: symbol.pathComponents
    )
  }

  /// Returns the developer.apple.com documentation URL for a framework
  /// path, for callers that have the path components without a full
  /// `IndexedSymbol`.
  ///
  /// - Parameters:
  ///   - framework: The framework the path belongs to.
  ///   - pathComponents: The path components identifying the symbol.
  /// - Returns: The documentation URL for the path.
  public func documentationURL(framework: String, pathComponents: [String])
    -> URL
  {
    DocumentationURLMapper.documentationURL(
      framework: framework, pathComponents: pathComponents
    )
  }
}
