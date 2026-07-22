import CoreModel

/// All extracted symbols for a single framework.
public struct FrameworkIndex: Sendable, Hashable, Codable {
  /// The framework's module name.
  public let moduleName: String
  /// The framework's extracted symbols.
  public let symbols: [IndexedSymbol]

  /// Creates a framework index from a module name and its symbols.
  ///
  /// - Parameters:
  ///   - moduleName: The framework's module name.
  ///   - symbols: The framework's extracted symbols.
  public init(moduleName: String, symbols: [IndexedSymbol]) {
    self.moduleName = moduleName
    self.symbols = symbols
  }

  /// Returns the symbol with the given USR, or `nil` if none exists.
  ///
  /// - Parameter usr: The USR to search for.
  /// - Returns: The matching symbol, or `nil` if none exists.
  /// - Complexity: O(*n*), scanning `symbols`. Callers performing many lookups
  ///   against the same index should build a `[String: IndexedSymbol]` map once
  ///   rather than calling this repeatedly.
  public func symbol(usr: String) -> IndexedSymbol? {
    symbols.first { $0.usr == usr }
  }
}
