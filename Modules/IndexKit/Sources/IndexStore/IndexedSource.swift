import CoreModel

/// One source's index in the store.
public struct IndexedSource: Sendable, Hashable, Identifiable {
  /// The source the index belongs to.
  public let source: Source
  /// The signature recorded when the index was built.
  public let signature: String?
  /// The number of symbols the source contributes.
  public let symbolCount: Int
  /// The approximate on-disk footprint, prorated from the database size.
  public let estimatedByteCount: Int64
  /// A stable identifier, the source's ID.
  public var id: Source.ID { source.id }

  /// Creates a summary of one source's index.
  ///
  /// - Parameters:
  ///   - source: The source the index belongs to.
  ///   - signature: The signature recorded when the index was built.
  ///   - symbolCount: The number of symbols the source contributes.
  ///   - estimatedByteCount: The approximate on-disk footprint, prorated
  ///     from the database size.
  public init(
    source: Source, signature: String?, symbolCount: Int,
    estimatedByteCount: Int64
  ) {
    self.source = source
    self.signature = signature
    self.symbolCount = symbolCount
    self.estimatedByteCount = estimatedByteCount
  }
}
