import ArgumentParser

@main
struct AppleAPIViewerCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "apple-api-viewer-cli",
    abstract: "Browse new Apple SDK API from the shared index.",
    subcommands: [
      Frameworks.self, Platforms.self, Search.self, New.self, Show.self,
      Summarize.self, Index.self, Xcode.self,
    ]
  )
}
