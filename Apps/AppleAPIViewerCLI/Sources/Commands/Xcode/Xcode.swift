import ArgumentParser

struct Xcode: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "xcode",
    abstract: "Manage the Xcodes the index can build from.",
    subcommands: [
      XcodeList.self, XcodeAdd.self, XcodeRemove.self, XcodeUse.self,
    ],
    defaultSubcommand: XcodeList.self
  )
}
