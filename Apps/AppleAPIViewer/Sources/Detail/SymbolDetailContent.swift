import AppleAPIViewerCore
import CoreModel
import SwiftUI
import SymbolGraphIndex
import WebKit

private enum DetailTab: String, CaseIterable, Identifiable {
  case overview = "Overview"
  case documentation = "Documentation"
  var id: String { rawValue }

  var titleKey: LocalizedStringKey {
    switch self {
    case .overview: "Overview"
    case .documentation: "Documentation"
    }
  }
}

struct SymbolDetailContent: View {
  let symbol: IndexedSymbol
  let moduleName: String
  let documentationURL: URL
  var change: SymbolChange?

  @State private var tab: DetailTab = .overview
  @Environment(\.openURL) private var openURL

  var body: some View {
    VStack(spacing: 0) {
      Picker("View", selection: $tab) {
        ForEach(DetailTab.allCases) { Text($0.titleKey).tag($0) }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .padding(.horizontal)
      .padding(.vertical, Spacing.small)

      Divider()

      switch tab {
      case .overview:
        overview
      case .documentation:
        WebView(url: documentationURL)
      }
    }
    .navigationTitle(symbol.name)
    .toolbar {
      ToolbarItem {
        Menu {
          symbolActions(
            name: symbol.name, url: documentationURL, openURL: openURL
          )
        } label: {
          Label("Share", systemImage: "square.and.arrow.up")
        }
        .help("Share or copy this API")
      }
    }
  }

  // MARK: - Subviews

  @ViewBuilder
  private var overview: some View {
    if let summary = symbol.summary, !summary.isEmpty {
      MarkdownDocumentView(
        markdown: DocCommentMarkdown.plainMarkdown(from: summary),
        documentId: symbol.usr
      ) {
        VStack(alignment: .leading, spacing: Spacing.medium) {
          metadataHeader
          Divider()
        }
        .padding(.horizontal, Spacing.xxLarge)
        .padding(.top, Spacing.xxLarge)
      }
    } else {
      ScrollView {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
          metadataHeader
          Text(
            "No inline documentation. Open the Documentation tab to read the full page."
          )
          .font(.callout)
          .foregroundStyle(.tertiary)
        }
        .padding(Spacing.xxLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private var metadataHeader: some View {
    VStack(alignment: .leading, spacing: Spacing.medium) {
      HStack(spacing: Spacing.medium) {
        Image(systemName: SymbolDisplay.systemImageName(for: symbol.kind))
          .font(.system(size: IconSize.detailHeader))
          .foregroundStyle(.tint)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
          if let change, change.old.title != symbol.title {
            Text(change.old.title)
              .font(.callout)
              .strikethrough()
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          }
          Text(symbol.title)
            .font(Typography.detailTitle)
            .textSelection(.enabled)
          Text("\(SymbolDisplay.label(for: symbol.kind)) · \(moduleName)")
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }

      availabilityPills
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .draggable(documentationURL)
  }

  private var availabilityPills: some View {
    GlassEffectContainer(spacing: Spacing.small) {
      FlowLayout(spacing: Spacing.small) {
        if let change {
          diffedPills(for: change)
        } else {
          ForEach(sortedAvailability, id: \.platform) { entry in
            AvailabilityPill(
              text:
              "\(entry.platform.displayName) \(BrowserModel.versionLabel(entry.version))"
            )
          }
          if symbol.isDeprecated {
            AvailabilityPill(
              text: String(localized: "Deprecated"), tint: .orange
            )
          }
        }
      }
    }
  }

  // One regular pill per platform keeps the diff inside the normal pill
  // layout. Extra tinted pills would double the row and break the look
  // of the browse view.
  @ViewBuilder
  private func diffedPills(for change: SymbolChange) -> some View {
    let old = change.old.introduced
    let new = change.new.introduced
    ForEach(Set(old.keys).union(new.keys).sorted()) { platform in
      let before = old[platform]
      let after = new[platform]
      if before == after, let after {
        AvailabilityPill(
          text:
          "\(platform.displayName) \(BrowserModel.versionLabel(after))"
        )
      } else {
        AvailabilityPill(
          Self.diffText(platform: platform, before: before, after: after)
        )
      }
    }
    if change.old.isDeprecated != change.new.isDeprecated {
      if change.new.isDeprecated {
        AvailabilityPill(
          Text(verbatim: "— ").strikethrough().foregroundStyle(.secondary)
            + Text("Deprecated"),
          tint: .orange
        )
      } else {
        AvailabilityPill(
          Text("Deprecated").strikethrough().foregroundStyle(.secondary)
        )
      }
    } else if symbol.isDeprecated {
      AvailabilityPill(text: String(localized: "Deprecated"), tint: .orange)
    }
    if change.reasons.contains(.signature) {
      AvailabilityPill(text: String(localized: "Signature changed"))
    }
  }

  private static func diffText(
    platform: ApplePlatform, before: SemanticVersion?, after: SemanticVersion?
  ) -> Text {
    let name = Text(verbatim: "\(platform.displayName) ")
    let struckBefore = Text(
      verbatim: before.map(BrowserModel.versionLabel) ?? "—"
    )
    .strikethrough()
    .foregroundStyle(.secondary)
    guard let after else {
      return (name + struckBefore).strikethrough().foregroundStyle(.secondary)
    }
    return name + struckBefore
      + Text(verbatim: " \(BrowserModel.versionLabel(after))")
  }

  private var sortedAvailability:
    [(platform: ApplePlatform, version: SemanticVersion)]
  {
    symbol.introduced
      .map { (platform: $0.key, version: $0.value) }
      .sorted { $0.platform < $1.platform }
  }
}

#Preview("Symbol Detail") {
  SymbolDetailContent(
    symbol: IndexedSymbol(
      usr: "s:9PencilKit8PKStrokeV11RenderStateV",
      title: "PKStroke.RenderState",
      kind: .structure,
      pathComponents: ["PKStroke", "RenderState"],
      parentUSR: "s:9PencilKit8PKStrokeV",
      introduced: [
        .iOS: SemanticVersion(major: 27), .macOS: SemanticVersion(major: 27),
        .visionOS: SemanticVersion(major: 27),
      ],
      isDeprecated: false,
      summary:
      "The render details of a stroke, including particle positioning and grain texture offset."
    ),
    moduleName: "PencilKit",
    documentationURL: URL(
      string:
      "https://developer.apple.com/documentation/pencilkit/pkstroke/renderstate"
    ) ?? URL(filePath: "/")
  )
  .frame(width: 480, height: 620)
}
