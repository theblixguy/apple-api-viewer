import ArgumentParser
import Dependencies
import IndexOrchestration
import IndexStore

struct XcodeRemove: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "remove",
    abstract: "Remove a manually added Xcode from the list."
  )

  @OptionGroup var options: GlobalOptions

  @Argument(help: "Xcode build number or application path to remove.")
  var reference: String

  func run() async throws {
    @Dependency(\.xcodeRegistry) var registry
    let entries = await registry.entries()
    let notFound = fail(
      "No managed Xcode matches '\(reference)'. Run 'apple-api-viewer-cli xcode list' to see the managed Xcodes.",
      code: ExitStatus.notFound,
      name: "notFound", format: options.format
    )
    guard let url = resolveXcodeReference(reference, in: entries) else {
      throw notFound
    }
    // A reference that resolves to a path outside the managed list is a
    // typo, not a removal.
    guard let entry = entries.first(where: {
      XcodeRegistry.canonicalPath(for: $0.applicationURL)
        == XcodeRegistry.canonicalPath(for: url)
    })
    else { throw notFound }
    guard entry.isManuallyAdded else {
      let build = entry.installation?.build ?? "<build>"
      throw fail(
        "\(reference) was found automatically and can't be removed. Delete its index with 'apple-api-viewer-cli index delete --xcode \(build)' instead.",
        code: ExitStatus.notRemovable, name: "notRemovable",
        format: options.format
      )
    }
    if let installation = entry.installation {
      _ = IndexStore.bootstrap(at: try options.indexURL())
      try? await IndexWorkspace(store: IndexStore())
        .deleteIndex(for: installation)
    }
    registry.remove(applicationURL: entry.applicationURL)
    emitOne(
      RemovedXcodeOutput(removed: url.path(percentEncoded: false)),
      as: options.format
    ) { "Removed \(reference)." }
  }
}

struct RemovedXcodeOutput: Encodable {
  let removed: String
}
