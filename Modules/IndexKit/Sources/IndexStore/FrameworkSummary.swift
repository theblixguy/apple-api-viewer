/// A framework with new API for the active selection, and its new-symbol count.
public struct FrameworkSummary: Sendable, Hashable, Identifiable {
  /// The framework's module name.
  public let moduleName: String
  /// The count of distinct new symbols in the framework for the given
  /// releases.
  public let newSymbolCount: Int
  /// A stable identifier, the module name.
  public var id: String { moduleName }

  /// Creates a framework summary from a module name and new-symbol count.
  ///
  /// - Parameters:
  ///   - moduleName: The framework's module name.
  ///   - newSymbolCount: The count of distinct new symbols in the framework
  ///     for the given releases.
  public init(moduleName: String, newSymbolCount: Int) {
    self.moduleName = moduleName
    self.newSymbolCount = newSymbolCount
  }
}
