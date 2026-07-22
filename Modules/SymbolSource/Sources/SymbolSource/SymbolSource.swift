import CoreModel
import SymbolGraphIndex

/// A place symbols come from.
///
/// A source enumerates and extracts its own frameworks, and the indexing
/// service drives one or more sources into the store. Conformers run
/// extraction off the main actor and honor task cancellation.
public protocol SymbolSource: Sendable {
  /// The source identity attributed to every framework this produces.
  var source: Source { get }

  /// Returns a fingerprint of the source's current inputs.
  ///
  /// The stored index is stale when this changes. For the SDK source, that is
  /// when Xcode or its SDKs change.
  ///
  /// - Returns: A fingerprint that changes when the source's inputs change.
  func signature() -> String

  /// Extracts every framework this source contributes, handing each finished
  /// framework to `consume` and reporting progress as units complete.
  ///
  /// A source may produce several frameworks with the same module name, one
  /// per input the module appears in, for example once per SDK. The
  /// consumer merges those by USR, keeping the first occurrence of each
  /// symbol.
  ///
  /// - Parameters:
  ///   - progress: Called as each unit finishes. Never throws.
  ///   - consume: Called with each finished framework. An error it throws
  ///     propagates out of this call.
  /// - Throws: An error from the source's extraction, or rethrown from
  ///   `consume`. Canceling the calling task stops extraction.
  func extractFrameworks(
    progress: @escaping @Sendable (IndexingProgress) async -> Void,
    consume: @escaping @Sendable (FrameworkIndex) async throws -> Void
  ) async throws

  /// Returns a single re-extracted framework, identified by module name.
  ///
  /// - Parameter moduleName: The module name to re-extract.
  /// - Returns: The re-extracted framework, or `nil` if this source has no
  ///   such framework.
  /// - Throws: An error from the source's extraction of the named module.
  func makeFramework(named moduleName: String) async throws -> FrameworkIndex?
}
