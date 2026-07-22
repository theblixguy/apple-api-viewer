import AppleAPIViewerCore
import SwiftUI
import SymbolGraphIndex
import UniformTypeIdentifiers

struct FrameworkOverviewView: View {
  let browser: BrowserModel
  let pick: FrameworkPick

  @State private var tree: [SymbolTreeNode] = []
  @State private var markdown = ""
  @State private var newSymbolCount = 0
  @State private var summary: SummaryState = .idle
  @State private var summaryTask: Task<Void, Never>?
  @State private var isExporting = false
  @State private var exportError: String?

  private enum SummaryState {
    case idle
    case running
    case done(String)
    case failed(String)
  }

  private struct LoadInputs: Hashable {
    let pick: FrameworkPick
    let selections: [VersionSelection]
    let kinds: Set<SymbolKind>
    let revision: Int
  }

  private var loadInputs: LoadInputs {
    LoadInputs(
      pick: pick, selections: browser.selections(for: pick.platform),
      kinds: browser.selectedKinds, revision: browser.dataRevision
    )
  }

  private var releasesLabel: String {
    NewAPIExport.releasesLabel(for: browser.selections(for: pick.platform))
  }

  private var releaseNames: String {
    browser.selections(for: pick.platform)
      .map {
        "\($0.platform.displayName) \(BrowserModel.versionLabel($0.version))"
      }
      .formatted(.list(type: .and))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Spacing.large) {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
          Text(pick.moduleName)
            .font(Typography.cardTitle)
          Text(
            "^[\(newSymbolCount) new APIs](inflect: true) in \(releaseNames)."
          )
          .font(.callout)
          .foregroundStyle(.secondary)
        }

        HStack(spacing: Spacing.small) {
          if FrameworkSummarizer.isAvailable {
            Button {
              runSummary()
            } label: {
              Label("Summarize what's new", systemImage: "sparkles")
            }
            .buttonStyle(.bordered)
            .disabled(tree.isEmpty || isSummarizing)
          }
          ShareLink(item: markdown)
            .buttonStyle(.bordered)
            .disabled(markdown.isEmpty)
          Button("Save as Markdown…") { isExporting = true }
            .buttonStyle(.bordered)
            .disabled(markdown.isEmpty)
        }

        summaryContent
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .task(id: loadInputs) {
      resetSummary()
      guard let loaded = await browser.tree(for: pick) else {
        tree = []
        markdown = ""
        newSymbolCount = 0
        return
      }
      tree = loaded
      newSymbolCount = NewAPIExport.matchCount(in: loaded)
      markdown = NewAPIExport.markdown(
        module: pick.moduleName,
        selections: browser.selections(for: pick.platform), tree: loaded
      )
    }
    .fileExporter(
      isPresented: $isExporting,
      document: MarkdownDocument(text: markdown),
      contentType: .markdownText,
      defaultFilename: "\(pick.moduleName) new APIs"
    ) { result in
      if case let .failure(error) = result {
        exportError = error.localizedDescription
      }
    }
    .alert(
      "Couldn't save the file",
      isPresented: Binding(
        get: { exportError != nil }, set: { if !$0 { exportError = nil } }
      ),
      presenting: exportError
    ) { _ in
      Button("OK") {}
    } message: { message in
      Text(verbatim: message)
    }
  }

  // MARK: - Subviews

  @ViewBuilder private var summaryContent: some View {
    switch summary {
    case .idle:
      EmptyView()
    case .running:
      HStack(spacing: Spacing.small) {
        ProgressView().controlSize(.small)
        Text("Summarizing…")
          .foregroundStyle(.secondary)
      }
    case let .done(text):
      VStack(alignment: .leading, spacing: Spacing.xSmall) {
        Label("Summary", systemImage: "sparkles")
          .font(.headline)
        Text(text)
          .textSelection(.enabled)
        Text("Generated on device. Check important details in the list.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(Spacing.medium)
      .background(
        .quaternary.opacity(0.5),
        in: .rect(cornerRadius: CornerRadius.inset)
      )
    case let .failed(message):
      Label {
        Text(verbatim: message)
      } icon: {
        Image(systemName: "exclamationmark.triangle")
      }
      .foregroundStyle(.secondary)
    }
  }

  // MARK: - Private

  private var isSummarizing: Bool {
    if case .running = summary { return true }
    return false
  }

  private func runSummary() {
    summaryTask?.cancel()
    summary = .running
    let module = pick.moduleName
    let releases = releasesLabel
    let tree = tree
    summaryTask = Task {
      do {
        let text = try await FrameworkSummarizer.summarize(
          module: module, releasesLabel: releases, tree: tree
        )
        guard !Task.isCancelled else { return }
        summary = .done(text)
      } catch {
        guard !Task.isCancelled else { return }
        summary = .failed(error.localizedDescription)
      }
    }
  }

  private func resetSummary() {
    summaryTask?.cancel()
    summaryTask = nil
    summary = .idle
  }
}
