import ArgumentParser
import Dependencies
import IndexOrchestration

struct XcodeUse: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "use",
    abstract: "Choose the Xcode the index builds from."
  )

  @OptionGroup var options: GlobalOptions

  @Flag(help: "Follow the Xcode that xcode-select points at.")
  var system = false

  @Argument(help: "Xcode build number or application path to build from.")
  var reference: String?

  func validate() throws {
    if system, reference != nil {
      throw ValidationError("Pass either an Xcode or --system, not both.")
    }
    if !system, reference == nil {
      throw ValidationError("Pass an Xcode build or path, or --system.")
    }
  }

  func run() async throws {
    @Dependency(\.xcodeRegistry) var registry
    if system {
      registry.clearDefault()
    } else if let reference {
      guard let url = await resolveXcodeReference(reference,
                                                  in: registry.entries())
      else {
        throw fail(
          "No Xcode matches '\(reference)'. Run 'apple-api-viewer-cli xcode list' to see the managed Xcodes.",
          code: ExitStatus.notFound,
          name: "notFound", format: options.format
        )
      }
      do {
        try registry.setDefault(applicationURL: url)
      } catch {
        throw fail(
          error.localizedDescription, code: ExitStatus.noXcode,
          name: "notAnXcode", format: options.format
        )
      }
    }

    let active = await registry.entries().first { $0.isDefault }.map(
      XcodeListItem.init
    )
    emitOne(ActiveXcodeOutput(active: active), as: options.format) {
      guard let active else { return "No Xcode available to build from." }
      return "Now building from \(active.displayName ?? active.path)."
    }
  }
}
