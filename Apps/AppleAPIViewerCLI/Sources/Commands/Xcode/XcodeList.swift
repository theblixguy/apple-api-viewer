import ArgumentParser
import Dependencies
import IndexOrchestration

struct XcodeList: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "list",
    abstract: "List the managed Xcodes. A star marks the default."
  )

  @OptionGroup var options: GlobalOptions

  func run() async throws {
    @Dependency(\.xcodeRegistry) var registry
    let items = await registry.entries().map(XcodeListItem.init)
    emit(items, as: options.format, line: xcodeListLine)
  }
}
