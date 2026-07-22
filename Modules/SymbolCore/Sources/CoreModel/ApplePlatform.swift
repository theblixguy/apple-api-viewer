/// An Apple OS platform an API can be available on.
public enum ApplePlatform: String, Sendable, CaseIterable, Codable, Hashable,
  Identifiable
{
  /// Apple's mobile OS.
  case iOS
  /// Apple's desktop OS.
  case macOS
  /// Apple's watch OS.
  case watchOS
  /// Apple's TV OS.
  case tvOS
  /// Apple's spatial computing OS.
  case visionOS

  /// A stable identifier, the raw platform name.
  public var id: String { rawValue }

  /// The `domain` string used in symbol-graph availability records and in
  /// `@available` attributes, such as `"iOS"` or `"macOS"`.
  public var availabilityDomain: String {
    switch self {
    case .iOS: "iOS"
    case .macOS: "macOS"
    case .watchOS: "watchOS"
    case .tvOS: "tvOS"
    case .visionOS: "visionOS"
    }
  }

  /// The OS token used in an LLVM target triple. For example, `ios` appears
  /// in `arm64-apple-ios27.0`, which is passed to `symbolgraph-extract`.
  public var targetTripleOS: String {
    switch self {
    case .iOS: "ios"
    case .macOS: "macos"
    case .watchOS: "watchos"
    case .tvOS: "tvos"
    case .visionOS: "xros"
    }
  }

  /// A user-facing name for the platform.
  public var displayName: String { availabilityDomain }

  /// Creates a platform from a symbol-graph availability `domain` string.
  ///
  /// Unrecognized domains, such as Mac Catalyst, the `*AppExtension`
  /// variants, and Swift language availability, return `nil`.
  ///
  /// - Parameter domain: The symbol-graph availability domain string.
  public init?(availabilityDomain domain: String) {
    switch domain {
    case "iOS", "iPadOS": self = .iOS
    case "macOS", "OSX": self = .macOS
    case "watchOS": self = .watchOS
    case "tvOS": self = .tvOS
    case "visionOS", "xrOS": self = .visionOS
    default: return nil
    }
  }
}

extension ApplePlatform: Comparable {
  /// Returns a Boolean value that indicates whether `lhs` precedes `rhs` in
  /// alphabetical order.
  ///
  /// - Parameters:
  ///   - lhs: A platform to compare.
  ///   - rhs: Another platform to compare.
  /// - Returns: `true` if `lhs` precedes `rhs`; otherwise, `false`.
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}
