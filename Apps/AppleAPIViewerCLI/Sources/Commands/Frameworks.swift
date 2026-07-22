import ArgumentParser
import IndexOrchestration
import IndexStore

struct Frameworks: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "List frameworks with API new in the given releases."
  )

  @OptionGroup var options: GlobalOptions
  @OptionGroup var indexSelection: IndexSelectionOptions

  @Option(
    name: .customLong("select"),
    help: "An OS release as platform:version like ios:26.0. Repeatable."
  )
  var releases: [ReleaseFilter] = []

  func run() async throws {
    let selections = try releases.requireSelections()
    let built = try await options.openBuiltQuery(
      xcodeBuild: indexSelection.xcodeBuild
    )
    let frameworks = try await built.query.frameworksWithNewSymbols(
      for: selections, source: built.source
    )
    let output = frameworks.map {
      FrameworkOutput(module: $0.moduleName, newSymbolCount: $0.newSymbolCount)
    }
    emit(output, as: options.format) { "\($0.module)  \($0.newSymbolCount)" }
  }
}

struct FrameworkOutput: Encodable {
  let module: String
  let newSymbolCount: Int
}
