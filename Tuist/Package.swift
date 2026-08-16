// swift-tools-version: 6.0
// Pinned to the toolchain version Tuist bundles for evaluating manifests,
// independent of the module packages.
import PackageDescription

#if TUIST
  import struct ProjectDescription.PackageSettings

  let packageSettings = PackageSettings()
#endif

let package = Package(
  name: "AppleAPIViewerDependencies",
  dependencies: [
    .package(path: "../Modules/SymbolCore"),
    .package(path: "../Modules/AppleSDKSource"),
    .package(path: "../Modules/IndexKit"),
    .package(path: "../Modules/AppleAPIViewerCore"),
    .package(
      url: "https://github.com/nodes-app/swift-markdown-engine",
      exact: "0.11.0"
    ),
    .package(
      url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.5"
    ),
    .package(
      url: "https://github.com/apple/swift-argument-parser", exact: "1.8.2"
    ),
  ]
)
