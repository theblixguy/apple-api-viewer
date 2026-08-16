import Foundation

/// The API differences between two snapshots of one framework.
///
/// A snapshot is one source's index of the framework, for example one Xcode's
/// SDK index. A symbol counts as added or removed when only one snapshot
/// contains its USR. A removed and an added declaration with the same kind
/// and path pair up as one ``SymbolChange``, because a signature change gives
/// a declaration a new USR. A symbol both snapshots contain counts as changed
/// when its deprecation state or availability differs.
public struct FrameworkDiff: Sendable, Hashable {
  /// The framework's module name.
  public let moduleName: String

  /// The symbols that only the new snapshot contains, in display order.
  public let added: [IndexedSymbol]

  /// The symbols that only the old snapshot contains, in display order.
  public let removed: [IndexedSymbol]

  /// The symbols that both snapshots contain with differences, in display
  /// order of their new records.
  public let changed: [SymbolChange]

  /// A Boolean value that indicates whether the two snapshots record the
  /// same API.
  public var isEmpty: Bool {
    added.isEmpty && removed.isEmpty && changed.isEmpty
  }

  /// Creates the diff between an old and a new snapshot of one framework.
  ///
  /// - Parameters:
  ///   - old: The old snapshot.
  ///   - new: The new snapshot, which names the diff's module.
  public init(from old: FrameworkIndex, to new: FrameworkIndex) {
    moduleName = new.moduleName
    let oldByUSR = Dictionary(
      old.symbols.map { ($0.usr, $0) }, uniquingKeysWith: { first, _ in first }
    )
    let newByUSR = Dictionary(
      new.symbols.map { ($0.usr, $0) }, uniquingKeysWith: { first, _ in first }
    )

    var changes: [SymbolChange] = []
    for (usr, newSymbol) in newByUSR {
      guard let oldSymbol = oldByUSR[usr] else { continue }
      let reasons = Self.recordDifferences(old: oldSymbol, new: newSymbol)
      guard !reasons.isEmpty else { continue }
      changes.append(
        SymbolChange(old: oldSymbol, new: newSymbol, reasons: reasons)
      )
    }

    // Overloads share a kind and path, so several candidates can qualify
    // for one pair. Pairing in USR order keeps the result deterministic.
    var addedByPath = Dictionary(
      grouping: newByUSR.values.filter { oldByUSR[$0.usr] == nil },
      by: PairKey.init
    )
    .mapValues { $0.sorted { $0.usr < $1.usr } }
    let removedOnly = oldByUSR.values
      .filter { newByUSR[$0.usr] == nil }
      .sorted { $0.usr < $1.usr }

    var unpairedRemoved: [IndexedSymbol] = []
    for oldSymbol in removedOnly {
      let key = PairKey(oldSymbol)
      guard var candidates = addedByPath[key], !candidates.isEmpty else {
        unpairedRemoved.append(oldSymbol)
        continue
      }
      let newSymbol = candidates.removeFirst()
      addedByPath[key] = candidates
      changes.append(
        SymbolChange(
          old: oldSymbol,
          new: newSymbol,
          reasons: Self.recordDifferences(old: oldSymbol, new: newSymbol)
            .union([.signature])
        )
      )
    }

    added = addedByPath.values.flatMap(\.self).sorted(by: Self.displayOrder)
    removed = unpairedRemoved.sorted(by: Self.displayOrder)
    changed = changes.sorted { Self.displayOrder($0.new, $1.new) }
  }

  // MARK: - Private

  private struct PairKey: Hashable {
    let kind: SymbolKind
    let pathComponents: [String]

    init(_ symbol: IndexedSymbol) {
      kind = symbol.kind
      pathComponents = symbol.pathComponents
    }
  }

  private static func recordDifferences(
    old: IndexedSymbol, new: IndexedSymbol
  ) -> Set<SymbolChange.Reason> {
    var reasons: Set<SymbolChange.Reason> = []
    if old.isDeprecated != new.isDeprecated {
      reasons.insert(.deprecation)
    }
    if Set(old.availability) != Set(new.availability) {
      reasons.insert(.availability)
    }
    return reasons
  }

  private static func displayOrder(
    _ lhs: IndexedSymbol, _ rhs: IndexedSymbol
  ) -> Bool {
    switch lhs.title.localizedCaseInsensitiveCompare(rhs.title) {
    case .orderedAscending: true
    case .orderedDescending: false
    case .orderedSame: lhs.usr < rhs.usr
    }
  }
}
