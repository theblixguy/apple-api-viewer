// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "AppleSDKSource",
  platforms: [
    .macOS(.v26),
  ],
  products: [
    .library(name: "SDKDiscovery", targets: ["SDKDiscovery"]),
    .library(name: "AppleSDKSource", targets: ["AppleSDKSource"]),
  ],
  dependencies: [
    .package(path: "../SymbolCore"),
    .package(path: "../SymbolSource"),
    .package(
      url: "https://github.com/swiftlang/swift-subprocess",
      exact: "0.5.0"
    ),
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
      name: "SDKDiscovery",
      dependencies: [
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "Dependencies", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "SymbolExtraction",
      dependencies: [
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "Subprocess", package: "swift-subprocess"),
        .product(name: "Dependencies", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "AppleSDKSource",
      dependencies: [
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "SymbolGraphIndex", package: "SymbolCore"),
        .product(name: "SymbolSource", package: "SymbolSource"),
        .product(name: "Dependencies", package: "swift-dependencies"),
        "SDKDiscovery",
        "SymbolExtraction",
      ]
    ),
    .testTarget(
      name: "SDKDiscoveryTests",
      dependencies: [
        "SDKDiscovery",
        .product(name: "CoreModel", package: "SymbolCore"),
      ]
    ),
    .testTarget(
      name: "SymbolExtractionTests",
      dependencies: [
        "SymbolExtraction", "SDKDiscovery",
        .product(name: "CoreModel", package: "SymbolCore"),
      ]
    ),
    .testTarget(
      name: "AppleSDKSourceTests",
      dependencies: [
        "AppleSDKSource", "SDKDiscovery",
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "SymbolGraphIndex", package: "SymbolCore"),
      ]
    ),
  ]
)
