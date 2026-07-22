import ArgumentParser
import CoreModel
import DocURLMapping
import Foundation
import IndexOrchestration
import SymbolGraphIndex

struct Show: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Show detail for one symbol by its USR."
  )

  // MARK: - Options

  @OptionGroup var options: GlobalOptions
  @OptionGroup var indexSelection: IndexSelectionOptions

  @Argument(help: "The symbol's USR.")
  var usr: String

  @Option(
    name: .customLong("module"),
    help: "The framework the symbol belongs to."
  )
  var module: String

  // MARK: - Run

  func run() async throws {
    let built = try await options.openBuiltQuery(
      xcodeBuild: indexSelection.xcodeBuild
    )
    guard let symbol = try await built.query.symbol(
      usr: usr, inModule: module, source: built.source
    )
    else {
      throw fail(
        "No symbol with USR \(usr) in \(module). Run 'apple-api-viewer-cli search' to find a symbol's USR.",
        code: ExitStatus.notFound, name: "notFound", format: options.format
      )
    }
    let url = DocumentationURLMapper.documentationURL(
      framework: module, pathComponents: symbol.pathComponents
    )
    let output = SymbolDetailOutput(symbol, module: module, url: url)
    emitOne(output, as: options.format) { Self.detailText(output) }
  }

  // MARK: - Helpers

  private static func detailText(_ detail: SymbolDetailOutput) -> String {
    var lines = ["\(detail.kind)  \(detail.title)", "Module \(detail.module)"]
    if !detail.introduced.isEmpty {
      let releases = detail.introduced.sorted { $0.key < $1.key }
        .map { "\($0.key) \($0.value)" }.joined(separator: ", ")
      lines.append("New in \(releases)")
    }
    if detail.deprecated { lines.append("Deprecated") }
    if let summary = detail.summary { lines.append(summary) }
    lines.append(detail.documentationURL)
    return lines.joined(separator: "\n")
  }
}

// MARK: - Output types

struct SymbolDetailOutput: Encodable {
  let usr: String
  let name: String
  let title: String
  let kind: String
  let module: String
  let path: [String]
  let deprecated: Bool
  let introduced: [String: String]
  let availability: [AvailabilityOutput]
  let summary: String?
  let documentationURL: String

  init(_ symbol: IndexedSymbol, module: String, url: URL) {
    usr = symbol.usr
    name = symbol.name
    title = symbol.title
    kind = symbol.kind.rawValue
    self.module = module
    path = symbol.pathComponents
    deprecated = symbol.isDeprecated
    introduced = introducedReleases(symbol)
    availability = symbol.availability.map(AvailabilityOutput.init)
    summary = symbol.summary
    documentationURL = url.absoluteString
  }
}

struct AvailabilityOutput: Encodable {
  let platform: String?
  let package: String?
  let introduced: String?

  init(_ availability: Availability) {
    switch availability.domain {
    case let .platform(platform):
      self.platform = platform.rawValue
      package = nil
    case let .package(name):
      platform = nil
      package = name
    }
    introduced = availability.introduced?.description
  }
}
