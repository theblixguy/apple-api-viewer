import ArgumentParser
import Dependencies
import IndexOrchestration

struct XcodeAdd: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "add",
    abstract: "Add an Xcode to the list by its application path."
  )

  @OptionGroup var options: GlobalOptions

  @Argument(help: "Path to an Xcode application bundle.")
  var path: String

  func run() async throws {
    @Dependency(\.xcodeRegistry) var registry
    let url = fileURL(forArgument: path)
    do {
      try await registry.add(applicationURL: url)
    } catch {
      throw fail(
        error.localizedDescription, code: ExitStatus.noXcode,
        name: "notAnXcode", format: options.format
      )
    }
    guard let item = await registry.entries().first(where: {
      XcodeRegistry.canonicalPath(for: $0.applicationURL)
        == XcodeRegistry.canonicalPath(for: url)
    }).map(XcodeListItem.init)
    else { return }
    emitOne(item, as: options.format) {
      "Added \(item.displayName ?? item.path)."
    }
  }
}
