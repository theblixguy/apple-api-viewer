import ArgumentParser
import CoreModel
import Foundation
import IndexOrchestration
import os

struct Build: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "Build or rebuild the index from the latest SDKs."
  )

  // MARK: - Options

  @OptionGroup var options: GlobalOptions

  @Option(
    name: .customLong("xcode"),
    help: "Build number of the Xcode to use. Defaults to the active Xcode."
  )
  var xcodeBuild: String?

  // MARK: - Run

  func run() async throws {
    let handles = try options.openIndex()
    try handles.requirePersistentStorage(format: options.format)
    let xcode = try await requireSelectedXcode(
      build: xcodeBuild, format: options.format
    )
    let format = options.format
    let quiet = options.quiet
    let last = OSAllocatedUnfairLock<IndexingProgress?>(initialState: nil)
    do {
      try await withInterruptCancellation {
        try await handles.workspace.buildIndex(for: xcode) { progress in
          last.withLock { $0 = progress }
          if !quiet { Self.report(progress, format: format) }
        }
      }
    } catch is CancellationError {
      Self.reportEvent("canceled", last.withLock { $0 }, format: format)
      throw ExitCode(130)
    } catch is IndexBuildInProgressError {
      throw fail(
        "Another index build is already running. Wait for it to finish, then try again.",
        code: ExitStatus.buildInProgress, name: "buildInProgress",
        format: format
      )
    }
    Self.reportEvent("done", last.withLock { $0 }, format: format)
  }

  // MARK: - Helpers

  private static func report(
    _ progress: IndexingProgress, format: OutputFormat
  ) {
    switch format {
    case .json:
      print(JSONLine.string(ProgressEvent("progress", progress)))
    case .text:
      if progress.phase == .saving {
        FileHandle.standardError.write(Data("\rSaving index…\u{001B}[K".utf8))
        return
      }
      let percent = Int((progress.fractionCompleted * 100).rounded())
      let module = progress.currentModule ?? ""
      let line =
        "\r\(progress.completed)/\(progress.total) \(percent)% \(module)"
      FileHandle.standardError.write(Data((line + "\u{001B}[K").utf8))
    }
  }

  private static func reportEvent(
    _ name: String, _ progress: IndexingProgress?, format: OutputFormat
  ) {
    switch format {
    case .json:
      print(JSONLine.string(ProgressEvent(name, progress)))
    case .text:
      FileHandle.standardError.write(Data("\n".utf8))
      print(name == "done" ? "Index built." : "Canceled.")
    }
  }
}

// MARK: - Output types

struct ProgressEvent: Encodable {
  let event: String
  let completed: Int?
  let total: Int?
  let module: String?
  let fraction: Double?
  let phase: String?

  init(_ event: String, _ progress: IndexingProgress?) {
    self.event = event
    completed = progress?.completed
    total = progress?.total
    module = progress?.currentModule
    fraction = progress?.fractionCompleted
    phase = progress?.phase.rawValue
  }
}
