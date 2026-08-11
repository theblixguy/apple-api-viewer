import SymbolGraphIndex

/// One row in the compare list, a symbol with how it differs between the
/// two compared indexes.
public struct DiffEntry: Hashable, Sendable, Identifiable {
  /// How a symbol differs between the two compared indexes.
  public enum Category: Hashable, Sendable {
    /// Only the active index contains the symbol.
    case added
    /// Only the compared index contains the symbol.
    case removed
    /// Both indexes contain the symbol, with the given differences.
    case changed(Set<SymbolChange.Reason>)
  }

  /// How the symbol differs between the two compared indexes.
  public let category: Category

  /// The record the entry shows: the new one for an added or changed
  /// symbol, and the old one for a removed symbol.
  public let symbol: IndexedSymbol

  /// The symbol's old and new records with their differences, for a
  /// changed symbol, or `nil` for the other categories.
  public let change: SymbolChange?

  /// A stable identifier, the shown record's USR.
  public var id: String { symbol.usr }

  /// Creates an entry from a symbol and how it differs.
  ///
  /// - Parameters:
  ///   - category: How the symbol differs between the two compared indexes.
  ///   - symbol: The record the entry shows.
  ///   - change: The symbol's old and new records with their differences,
  ///     for a changed symbol.
  public init(
    category: Category, symbol: IndexedSymbol, change: SymbolChange? = nil
  ) {
    self.category = category
    self.symbol = symbol
    self.change = change
  }
}
