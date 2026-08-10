// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "IndexKit",
  platforms: [
    .macOS(.v26),
  ],
  products: [
    .library(name: "IndexStore", targets: ["IndexStore"]),
    .library(name: "IndexOrchestration", targets: ["IndexOrchestration"]),
  ],
  dependencies: [
    .package(path: "../SymbolCore"),
    .package(path: "../SymbolSource"),
    .package(path: "../AppleSDKSource"),
    .package(url: "https://github.com/pointfreeco/sqlite-data", exact: "1.9.0"),
    .package(
      url: "https://github.com/pointfreeco/swift-dependencies",
      exact: "1.14.1"
    ),
    .package(
      url: "https://github.com/swiftlang/swift-docc-plugin", exact: "1.5.0"
    ),
  ],
  targets: [
    .target(
      name: "IndexStore",
      dependencies: [
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "SymbolGraphIndex", package: "SymbolCore"),
        .product(name: "SQLiteData", package: "sqlite-data"),
        .product(name: "Dependencies", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "IndexingService",
      dependencies: [
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "SymbolGraphIndex", package: "SymbolCore"),
        .product(name: "SymbolSource", package: "SymbolSource"),
        .product(name: "AppleSDKSource", package: "AppleSDKSource"),
        "IndexStore",
      ]
    ),
    .target(
      name: "IndexOrchestration",
      dependencies: [
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "SymbolGraphIndex", package: "SymbolCore"),
        .product(name: "SDKDiscovery", package: "AppleSDKSource"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        "IndexStore",
        "IndexingService",
      ]
    ),
    .target(
      name: "TestSupport",
      dependencies: [
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "SymbolGraphIndex", package: "SymbolCore"),
      ],
      path: "Tests/TestSupport"
    ),
    .testTarget(
      name: "IndexStoreTests",
      dependencies: [
        "IndexStore",
        "TestSupport",
        .product(name: "SymbolGraphIndex", package: "SymbolCore"),
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(
          name: "DependenciesTestSupport", package: "swift-dependencies"
        ),
      ]
    ),
    .testTarget(
      name: "IndexingServiceTests",
      dependencies: [
        "IndexingService", "IndexStore",
        .product(name: "SymbolSource", package: "SymbolSource"),
        .product(name: "SymbolGraphIndex", package: "SymbolCore"),
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(
          name: "DependenciesTestSupport", package: "swift-dependencies"
        ),
      ]
    ),
    .testTarget(
      name: "IndexOrchestrationTests",
      dependencies: [
        "IndexOrchestration",
        "IndexStore",
        "TestSupport",
        .product(name: "SymbolGraphIndex", package: "SymbolCore"),
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "SDKDiscovery", package: "AppleSDKSource"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(
          name: "DependenciesTestSupport", package: "swift-dependencies"
        ),
      ]
    ),
  ]
)
