// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "SymbolSource",
  platforms: [
    .macOS(.v26),
  ],
  products: [
    .library(name: "SymbolSource", targets: ["SymbolSource"]),
  ],
  dependencies: [
    .package(path: "../SymbolCore"),
    .package(
      url: "https://github.com/swiftlang/swift-docc-plugin", exact: "1.5.0"
    ),
  ],
  targets: [
    .target(
      name: "SymbolSource",
      dependencies: [
        .product(name: "CoreModel", package: "SymbolCore"),
        .product(name: "SymbolGraphIndex", package: "SymbolCore"),
      ]
    ),
  ]
)
