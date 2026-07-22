import ArgumentParser

struct Index: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "index",
    abstract: "Build and inspect the index.",
    subcommands: [Build.self, Status.self, Reindex.self, Delete.self]
  )
}
