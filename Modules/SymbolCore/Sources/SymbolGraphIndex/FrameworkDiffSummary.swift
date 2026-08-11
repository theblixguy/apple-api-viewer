/// A framework's diff reduced to its per-category symbol counts.
public struct FrameworkDiffSummary: Sendable, Hashable, Identifiable {
  /// The framework's module name.
  public let moduleName: String

  /// The count of symbols that only the new snapshot contains.
  public let addedCount: Int

  /// The count of symbols that only the old snapshot contains.
  public let removedCount: Int

  /// The count of symbols that both snapshots contain with differences.
  public let changedCount: Int

  /// A stable identifier, the module name.
  public var id: String { moduleName }

  /// A Boolean value that indicates whether the two snapshots record the
  /// same API.
  public var isEmpty: Bool {
    addedCount == 0 && removedCount == 0 && changedCount == 0
  }

  /// Creates a summary from a module name and its per-category counts.
  ///
  /// - Parameters:
  ///   - moduleName: The framework's module name.
  ///   - addedCount: The count of symbols that only the new snapshot
  ///     contains.
  ///   - removedCount: The count of symbols that only the old snapshot
  ///     contains.
  ///   - changedCount: The count of symbols that both snapshots contain
  ///     with differences.
  public init(
    moduleName: String, addedCount: Int, removedCount: Int, changedCount: Int
  ) {
    self.moduleName = moduleName
    self.addedCount = addedCount
    self.removedCount = removedCount
    self.changedCount = changedCount
  }

  /// Creates the summary of a framework diff.
  ///
  /// - Parameter diff: The diff to summarize.
  public init(_ diff: FrameworkDiff) {
    self.init(
      moduleName: diff.moduleName,
      addedCount: diff.added.count,
      removedCount: diff.removed.count,
      changedCount: diff.changed.count
    )
  }
}
