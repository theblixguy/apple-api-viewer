/// The symbol a comparison focuses on.
///
/// Carrying the display name lets the UI describe the symbol when the
/// compared indexes record no changes to it, where no diff entry exists
/// to read the name from.
public struct DiffFocus: Hashable, Sendable {
  /// The symbol's USR.
  public let usr: String

  /// The symbol's display name.
  public let name: String

  /// Creates a focus on the symbol with the given USR and name.
  ///
  /// - Parameters:
  ///   - usr: The symbol's USR.
  ///   - name: The symbol's display name.
  public init(usr: String, name: String) {
    self.usr = usr
    self.name = name
  }
}
