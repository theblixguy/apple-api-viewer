import SymbolGraphIndex

extension BrowserModel {
  /// The active symbol-kind filter, or `nil` when every kind is shown.
  public var kindFilter: Set<SymbolKind>? {
    selectedKinds.isEmpty ? nil : selectedKinds
  }

  /// Returns a Boolean value that indicates whether `kind` is in the active
  /// kind filter.
  ///
  /// - Parameter kind: The symbol kind to check.
  /// - Returns: `true` when the kind is in the active kind filter.
  public func isKindSelected(_ kind: SymbolKind) -> Bool {
    selectedKinds.contains(kind)
  }

  /// Adds or removes a kind from the filter.
  ///
  /// - Parameter kind: The symbol kind to add or remove.
  public func toggleKind(_ kind: SymbolKind) {
    if selectedKinds.contains(kind) {
      selectedKinds.remove(kind)
    } else {
      selectedKinds.insert(kind)
    }
  }

  /// Clears the kind filter.
  public func clearKinds() {
    selectedKinds = []
  }
}
