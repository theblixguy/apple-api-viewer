import Testing
@testable import AppleAPIViewerCore

@Suite("Doc comment markdown", .tags(.documentation))
struct DocCommentMarkdownTests {
  @Test("Plain summary passes through unchanged")
  func plainSummaryPassesThroughUnchanged() {
    let summary = """
    A request for the age range of a person.

    Use `AgeRangeService` to request a person's age range.
    """
    #expect(DocCommentMarkdown.plainMarkdown(from: summary) == summary)
  }

  @Test("Tab navigators unwrap into labeled sections")
  func tabNavigatorUnwrapsIntoLabeledSections() {
    let summary = """
    Intro text.

    @TabNavigator {
    @Tab("SwiftUI") {
    ```swift
    let a = 1
    ```
    }
    @Tab("UIKit and AppKit") {
    ```swift
    let b = 2
    ```
    }
    }
    """
    let result = DocCommentMarkdown.plainMarkdown(from: summary)
    #expect(!result.contains("@Tab"))
    #expect(!result.contains("@TabNavigator"))
    #expect(result.contains("**SwiftUI**"))
    #expect(result.contains("**UIKit and AppKit**"))
    #expect(!result.contains("\n}"))
    let fenceCount = result.components(separatedBy: "```").count - 1
    #expect(fenceCount == 4)
  }

  @Test("Fenced code keeps directive looking lines")
  func fencedCodeKeepsDirectiveLookingLines() {
    let summary = """
    ```swift
    @Environment(\\.requestAgeRange) var requestAgeRange
    if done {
    }
    ```
    """
    #expect(DocCommentMarkdown.plainMarkdown(from: summary) == summary)
  }

  @Test("Comment blocks are dropped")
  func commentBlocksAreDropped() {
    let summary = """
    Kept.
    @Comment {
    Internal note with a fence:
    ```swift
    let hidden = true
    ```
    }
    Also kept.
    """
    let result = DocCommentMarkdown.plainMarkdown(from: summary)
    #expect(result.contains("Kept."))
    #expect(result.contains("Also kept."))
    #expect(!result.contains("Internal note"))
    #expect(!result.contains("hidden"))
  }

  @Test("Deprecation summary is labeled")
  func deprecationSummaryIsLabeled() {
    let summary = """
    @DeprecationSummary {
    Use the newer API instead.
    }
    """
    let result = DocCommentMarkdown.plainMarkdown(from: summary)
    #expect(result.contains("**Deprecated**"))
    #expect(result.contains("Use the newer API instead."))
    #expect(!result.contains("@DeprecationSummary"))
  }

  @Test("Single line directives are dropped and bare mentions kept")
  func singleLineDirectivesAreDroppedAndBareMentionsKept() {
    let summary = """
    @Image(source: "chart", alt: "A chart")
    @MainActor
    Prose stays.
    """
    let result = DocCommentMarkdown.plainMarkdown(from: summary)
    #expect(!result.contains("@Image"))
    #expect(result.contains("@MainActor"))
    #expect(result.contains("Prose stays."))
  }

  @Test("Brace outside directives is untouched")
  func braceOutsideDirectivesIsUntouched() {
    let summary = """
    A closure looks like { value in value }.
    }
    """
    #expect(DocCommentMarkdown.plainMarkdown(from: summary) == summary)
  }
}
