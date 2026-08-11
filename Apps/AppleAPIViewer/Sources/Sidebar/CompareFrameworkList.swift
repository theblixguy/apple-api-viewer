import AppleAPIViewerCore
import CoreModel
import SwiftUI
import SymbolGraphIndex

struct CompareFrameworkList: View {
  @Bindable var browser: BrowserModel
  @State private var summaries: [FrameworkDiffSummary] = []
  @State private var isLoading = false

  private struct ReloadKey: Hashable {
    let source: Source.ID?
    let revision: Int
  }

  var body: some View {
    List(selection: $browser.selectedDiffModule) {
      if summaries.isEmpty {
        if !isLoading {
          ContentUnavailableView(
            "No differences",
            systemImage: "plus.forwardslash.minus",
            description: Text("Both indexes record the same API.")
          )
        }
      } else {
        Section("Changed frameworks") {
          ForEach(summaries) { summary in
            Label(summary.moduleName, systemImage: "shippingbox")
              .badge(Text(verbatim: Self.badgeLabel(for: summary)))
              .tag(summary.moduleName)
          }
        }
      }
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      header
    }
    .task(
      id: ReloadKey(
        source: browser.comparisonSource, revision: browser.dataRevision
      )
    ) {
      await loadSummaries()
    }
  }

  // MARK: - Private

  // Exiting compare mode lives in the toolbar picker as "Off", so the
  // header only names the baseline.
  private var header: some View {
    HStack(spacing: Spacing.small) {
      VStack(alignment: .leading, spacing: 0) {
        Text("Comparing with")
          .font(Typography.sectionLabel)
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
        Text(verbatim: browser.comparisonDisplayName ?? "")
          .font(.callout)
      }
      Spacer(minLength: 0)
      if isLoading {
        ProgressView()
          .controlSize(.small)
          .accessibilityLabel("Comparing")
      }
    }
    .padding(Spacing.medium)
    .background(.bar)
  }

  private func loadSummaries() async {
    isLoading = true
    defer { isLoading = false }
    if let loaded = await browser.diffSummaries() {
      summaries = loaded
    }
    // A re-index can drop the selected framework from the list. Without
    // this, the content column would keep showing its stale diff. A
    // focused comparison is exempt, because a framework with no changes
    // has no row on purpose.
    if browser.focusedDiff == nil,
       let module = browser.selectedDiffModule,
       !summaries.contains(where: { $0.moduleName == module })
    {
      browser.selectedDiffModule = nil
    }
  }

  private static func badgeLabel(for summary: FrameworkDiffSummary) -> String {
    var parts: [String] = []
    if summary.addedCount > 0 { parts.append("+\(summary.addedCount)") }
    if summary.removedCount > 0 { parts.append("−\(summary.removedCount)") }
    if summary.changedCount > 0 { parts.append("~\(summary.changedCount)") }
    return parts.joined(separator: " ")
  }
}
