import ArgumentParser
import IndexOrchestration

struct Reindex: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Re-extract one framework in place."
  )

  @OptionGroup var options: GlobalOptions

  @Option(
    name: .customLong("xcode"),
    help: "Build number of the Xcode to use. Defaults to the active Xcode."
  )
  var xcodeBuild: String?

  @Argument(help: "The framework to re-extract.")
  var module: String

  func run() async throws {
    let handles = try options.openIndex()
    try handles.requirePersistentStorage(format: options.format)
    let xcode = try await requireSelectedXcode(
      build: xcodeBuild, format: options.format
    )
    guard try await handles.workspace.reindexModule(module, for: xcode) else {
      throw fail(
        "\(module) is not in any of \(xcode.displayName)'s SDKs. Run 'apple-api-viewer-cli frameworks' to list the indexed frameworks.",
        code: ExitStatus.notFound, name: "notFound", format: options.format
      )
    }
    let output = ReindexOutput(module: module, status: "reindexed")
    emitOne(output, as: options.format) { "Re-indexed \(module)." }
  }
}

struct ReindexOutput: Encodable {
  let module: String
  let status: String
}
