import Foundation

// The app shows `errorDescription` when a build fails with this error.
package struct ToolchainChangedError: Error, LocalizedError {
  package var errorDescription: String? {
    String(
      localized: """
      The Xcode toolchain changed while the index was building. Build the \
      index again.
      """
    )
  }

  package init() {}
}
