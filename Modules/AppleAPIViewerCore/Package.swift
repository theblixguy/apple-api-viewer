// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "AppleAPIViewerCore",
  defaultLocalization: "en",
  platforms: [
    .macOS(.v26),
  ],
  products: [
    .library(name: "AppleAPIViewerCore", targets: ["AppleAPIViewerCore"]),
  ],
  dependencies: [
    .package(path: "../SymbolCore"),
    .package(path: "../IndexKit"),
    .package(url: "https://github.com/pointfreeco/sqlite-data", exact: "1.9.0"),
    .package(
      url: "https://github.com/pointfreeco/swift-dependencies",
      exact: "1.14.1"
    ),
    .package(
      url: "https://github.com/apple/swift-async-algorithms", exact: "1.1.5"
    ),
    .package(
      url: "https://github.com/swiftlang/swift-docc-plugin", exact: "1.5.0"
    ),
  ],
  targets: [
    .target(
      name: "AppleAPIViewerCore",
      dependencies: [
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "SymbolGraphIndex", package: "SymbolCore"),
        .product(name: "DocURLMapping", package: "SymbolCore"),
        .product(name: "IndexStore", package: "IndexKit"),
        .product(name: "IndexOrchestration", package: "IndexKit"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(
          name: "AsyncAlgorithms", package: "swift-async-algorithms"
        ),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
      ]
    ),
    .testTarget(
      name: "AppleAPIViewerCoreTests",
      dependencies: [
        "AppleAPIViewerCore",
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "SymbolGraphIndex", package: "SymbolCore"),
        .product(name: "IndexStore", package: "IndexKit"),
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(
          name: "DependenciesTestSupport", package: "swift-dependencies"
        ),
      ],
      swiftSettings: [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
      ]
    ),
  ]
)
