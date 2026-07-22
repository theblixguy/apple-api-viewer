import ProjectDescription

let bundleIDPrefix = "com.suyashsrijan"

let project = Project(
  name: "AppleAPIViewer",
  options: .options(
    defaultKnownRegions: ["en"],
    developmentRegion: "en"
  ),
  settings: .settings(
    base: [
      "SWIFT_VERSION": "6.0",
      "SWIFT_APPROACHABLE_CONCURRENCY": "YES",
      "ENABLE_HARDENED_RUNTIME": "YES",
      "MARKETING_VERSION": "0.1.0",
      "CURRENT_PROJECT_VERSION": "1",
    ]
  ),
  targets: [
    .target(
      name: "apple-api-viewer",
      destinations: .macOS,
      product: .app,
      bundleId: "\(bundleIDPrefix).apple-api-viewer",
      deploymentTargets: .macOS("26.0"),
      infoPlist: .extendingDefault(with: [
        "CFBundleName": "Apple API Viewer",
        "CFBundleDisplayName": "Apple API Viewer",
        "CFBundleShortVersionString": "$(MARKETING_VERSION)",
        "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
        "LSApplicationCategoryType": "public.app-category.developer-tools",
        "SUFeedURL":
          "https://raw.githubusercontent.com/theblixguy/apple-api-viewer/main/appcast.xml",
        "SUPublicEDKey": "LY50TOUF4QhitcbZgLtr0n9WmINKSVEzl1JG6IN6pXg=",
      ]),
      sources: ["Apps/AppleAPIViewer/Sources/**"],
      resources: ["Apps/AppleAPIViewer/Resources/**"],
      copyFiles: [
        .wrapper(
          name: "Embed CLI",
          subpath: "Contents/Helpers",
          files: [
            .buildProduct(name: "apple-api-viewer-cli", codeSignOnCopy: true),
          ]
        ),
      ],
      dependencies: [
        .target(name: "apple-api-viewer-cli"),
        .external(name: "Sparkle"),
        .external(name: "AppleAPIViewerCore"),
        .external(name: "CoreModel"),
        .external(name: "SymbolGraphIndex"),
        .external(name: "IndexStore"),
        .external(name: "IndexOrchestration"),
        .external(name: "MarkdownEngine"),
        .external(name: "MarkdownEngineCodeBlocks"),
        .external(name: "Dependencies"),
      ],
      settings: .settings(
        base: [
          "SWIFT_DEFAULT_ACTOR_ISOLATION": "MainActor",
          "CODE_SIGN_STYLE": "Automatic",
          "CODE_SIGN_IDENTITY": "Apple Development",
          "DEVELOPMENT_TEAM": "97346KBR2S",
          "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        ]
      )
    ),
    .target(
      name: "apple-api-viewer-cli",
      destinations: .macOS,
      product: .commandLineTool,
      bundleId: "\(bundleIDPrefix).apple-api-viewer.cli",
      deploymentTargets: .macOS("26.0"),
      infoPlist: .default,
      sources: ["Apps/AppleAPIViewerCLI/Sources/**"],
      dependencies: [
        .external(name: "ArgumentParser"),
        .external(name: "CoreModel"),
        .external(name: "SymbolGraphIndex"),
        .external(name: "IndexStore"),
        .external(name: "IndexOrchestration"),
        .external(name: "DocURLMapping"),
        .external(name: "Dependencies"),
        .external(name: "AppleAPIViewerCore"),
      ],
      settings: .settings(
        base: [
          // The CLI ships inside the app bundle. Without this, the archive
          // would install the tool as a second product and become a
          // generic archive, which cannot export with the developer-id
          // method.
          "SKIP_INSTALL": "YES",
        ]
      )
    ),
    .target(
      name: "apple-api-viewer-cli-tests",
      destinations: .macOS,
      product: .unitTests,
      bundleId: "\(bundleIDPrefix).apple-api-viewer.cli.tests",
      deploymentTargets: .macOS("26.0"),
      infoPlist: .default,
      sources: [
        .glob(
          "Apps/AppleAPIViewerCLI/Sources/**",
          excluding: ["Apps/AppleAPIViewerCLI/Sources/AppleAPIViewerCLI.swift"]
        ),
        "Apps/AppleAPIViewerCLI/Tests/**",
      ],
      dependencies: [
        .external(name: "ArgumentParser"),
        .external(name: "CoreModel"),
        .external(name: "SymbolGraphIndex"),
        .external(name: "IndexStore"),
        .external(name: "IndexOrchestration"),
        .external(name: "DocURLMapping"),
        .external(name: "Dependencies"),
        .external(name: "AppleAPIViewerCore"),
      ]
    ),
  ]
)
