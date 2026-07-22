import CoreModel

/// Identifies a framework picked in the sidebar, under one platform.
///
/// The type does not store releases. Callers read them live from the
/// model's current selection. The tree reflects the active version
/// filter, not a version frozen at pick time.
public struct FrameworkPick: Hashable, Sendable {
  /// The platform the framework was picked under.
  public let platform: ApplePlatform
  /// The framework (module) name.
  public let moduleName: String

  /// Creates a pick for the given framework under the given platform.
  ///
  /// - Parameters:
  ///   - platform: The platform the framework was picked under.
  ///   - moduleName: The framework (module) name.
  public init(platform: ApplePlatform, moduleName: String) {
    self.platform = platform
    self.moduleName = moduleName
  }
}
