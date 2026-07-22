/// Progress of an index build.
public struct IndexingProgress: Sendable, Hashable {
  /// The stage the build is in.
  public enum Phase: String, Sendable, Hashable {
    /// The build extracts and parses module symbol graphs.
    case extracting
    /// The build writes the completed index to storage.
    case saving
  }

  /// The number of completed work units.
  public let completed: Int
  /// The total number of work units.
  public let total: Int
  /// The module that just finished, if any.
  public let currentModule: String?
  /// The stage the build is in.
  public let phase: Phase

  /// The completed fraction in `0...1`. The value is `1` when there is no
  /// work.
  public var fractionCompleted: Double {
    total == 0 ? 1 : Double(completed) / Double(total)
  }

  /// Creates a progress value from completed and total counts, the current
  /// module, and the build stage.
  ///
  /// - Parameters:
  ///   - completed: The number of completed work units.
  ///   - total: The total number of work units.
  ///   - currentModule: The module that just finished, if any.
  ///   - phase: The stage the build is in.
  public init(
    completed: Int, total: Int, currentModule: String?,
    phase: Phase = .extracting
  ) {
    self.completed = completed
    self.total = total
    self.currentModule = currentModule
    self.phase = phase
  }
}
