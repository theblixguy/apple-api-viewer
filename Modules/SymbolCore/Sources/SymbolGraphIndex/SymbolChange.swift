/// One API that both snapshots contain, with the differences between its two
/// records.
public struct SymbolChange: Sendable, Hashable, Identifiable {
  /// A difference between a symbol's two records.
  public enum Reason: String, Sendable, Hashable, Codable, CaseIterable {
    /// The snapshots declare the symbol at the same path with different
    /// USRs, which indicates a signature change.
    case signature
    /// The snapshots record different deprecation states.
    case deprecation
    /// The snapshots record different availability.
    case availability
  }

  /// The symbol as the old snapshot records it.
  public let old: IndexedSymbol

  /// The symbol as the new snapshot records it.
  public let new: IndexedSymbol

  /// The differences between the two records.
  public let reasons: Set<Reason>

  /// A stable identifier, the new record's USR.
  public var id: String { new.usr }

  /// Creates a change from a symbol's two records and their differences.
  ///
  /// - Parameters:
  ///   - old: The symbol as the old snapshot records it.
  ///   - new: The symbol as the new snapshot records it.
  ///   - reasons: The differences between the two records.
  public init(old: IndexedSymbol, new: IndexedSymbol, reasons: Set<Reason>) {
    self.old = old
    self.new = new
    self.reasons = reasons
  }
}
