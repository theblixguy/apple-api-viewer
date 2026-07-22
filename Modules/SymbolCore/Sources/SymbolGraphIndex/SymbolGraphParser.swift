import CoreModel
import Foundation
import SymbolKit

/// Decodes a `.symbols.json` symbol graph into a framework index.
///
/// `swift symbolgraph-extract` produces the graph. SymbolKit's format types
/// decode it.
public enum SymbolGraphParser {
  static let synthesizedMarker = "::SYNTHESIZED::"

  /// Returns a framework index decoded from raw `.symbols.json` data.
  ///
  /// - Parameters:
  ///   - data: The raw `.symbols.json` data to decode.
  ///   - moduleNameOverride: Replaces the module name from the graph, for
  ///     example to force the primary name onto a cross-import overlay.
  /// - Returns: The framework index decoded from the graph.
  /// - Throws: `DecodingError` when `data` is not a valid symbol graph.
  public static func parse(_ data: Data, moduleNameOverride: String? = nil)
    throws -> FrameworkIndex
  {
    let graph = try JSONDecoder().decode(SymbolGraph.self, from: data)
    return parse(graph, moduleNameOverride: moduleNameOverride)
  }

  static func parse(
    _ graph: SymbolGraph, moduleNameOverride: String? = nil
  )
    -> FrameworkIndex
  {
    let moduleName = moduleNameOverride ?? graph.module.name
    let parentByUSR = parentMap(from: graph.relationships)

    var symbols: [IndexedSymbol] = []
    symbols.reserveCapacity(graph.symbols.count)

    for (usr, symbol) in graph.symbols where !usr.contains(synthesizedMarker) {
      symbols.append(
        IndexedSymbol(
          usr: usr,
          title: symbol.names.title,
          kind: SymbolKind(
            symbolGraphIdentifier: symbol.kind.identifier.identifier
          ),
          pathComponents: symbol.pathComponents,
          parentUSR: parentByUSR[usr],
          introduced: introducedVersions(from: symbol),
          isDeprecated: isDeprecated(symbol),
          summary: summary(from: symbol)
        )
      )
    }

    symbols.sort { $0.usr < $1.usr }
    return FrameworkIndex(moduleName: moduleName, symbols: symbols)
  }

  /// Returns a framework index that merges a primary framework graph with
  /// its cross-import overlays, de-duplicating by USR. Overlay files look
  /// like `PencilKit@UIKit.symbols.json`, emitted when one framework adds
  /// API to a type from another.
  ///
  /// - Parameters:
  ///   - indexes: The primary framework graph, followed by its cross-import
  ///     overlays. The first occurrence of each USR wins.
  ///   - moduleName: The module name for the merged index.
  /// - Returns: The merged framework index.
  public static func merge(_ indexes: [FrameworkIndex], moduleName: String)
    -> FrameworkIndex
  {
    var byUSR: [String: IndexedSymbol] = [:]
    for index in indexes {
      for symbol in index.symbols where byUSR[symbol.usr] == nil {
        byUSR[symbol.usr] = symbol
      }
    }
    return FrameworkIndex(
      moduleName: moduleName,
      symbols: byUSR.values.sorted { $0.usr < $1.usr }
    )
  }

  // MARK: - Private

  private static func parentMap(from relationships: [SymbolGraph.Relationship])
    -> [String: String]
  {
    var parentByUSR: [String: String] = [:]
    for relationship in relationships where relationship.kind == .memberOf {
      guard !relationship.source.contains(synthesizedMarker) else { continue }
      if parentByUSR[relationship.source] == nil {
        parentByUSR[relationship.source] = relationship.target
      }
    }
    return parentByUSR
  }

  private static func introducedVersions(from symbol: SymbolGraph.Symbol)
    -> [ApplePlatform:
      SemanticVersion]
  {
    var introduced: [ApplePlatform: SemanticVersion] = [:]
    for item in symbol.availability ?? [] {
      guard let domain = item.domain?.rawValue,
            let platform = ApplePlatform(availabilityDomain: domain),
            let version = item.introducedVersion
      else { continue }
      let semantic = SemanticVersion(
        major: version.major, minor: version.minor, patch: version.patch
      )
      introduced[platform] =
        introduced[platform].map { min($0, semantic) } ?? semantic
    }
    return introduced
  }

  private static func isDeprecated(_ symbol: SymbolGraph.Symbol) -> Bool {
    (symbol.availability ?? []).contains { item in
      item.isUnconditionallyDeprecated || item.deprecatedVersion != nil
    }
  }

  private static func summary(from symbol: SymbolGraph.Symbol) -> String? {
    guard let lines = symbol.docComment?.lines, !lines.isEmpty else {
      return nil
    }
    let text = lines.map(\.text).joined(separator: "\n").trimmingCharacters(
      in: .whitespacesAndNewlines
    )
    return text.isEmpty ? nil : text
  }
}
