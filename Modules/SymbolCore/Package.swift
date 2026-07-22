// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "SymbolCore",
  platforms: [
    .macOS(.v26),
  ],
  products: [
    .library(name: "CoreModel", targets: ["CoreModel"]),
    .library(name: "DocURLMapping", targets: ["DocURLMapping"]),
    .library(name: "SymbolGraphIndex", targets: ["SymbolGraphIndex"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/swiftlang/swift-docc-symbolkit",
      revision: "cf6249d437ae23fb46a1c735d0240edb23cc35a8"
    ),
    .package(
      url: "https://github.com/swiftlang/swift-docc-plugin", exact: "1.5.0"
    ),
  ],
  targets: [
    .target(name: "CoreModel"),
    .target(
      name: "DocURLMapping"
    ),
    .target(
      name: "SymbolGraphIndex",
      dependencies: [
        "CoreModel",
        .product(name: "SymbolKit", package: "swift-docc-symbolkit"),
      ]
    ),
    .testTarget(
      name: "CoreModelTests",
      dependencies: ["CoreModel"]
    ),
    .testTarget(
      name: "DocURLMappingTests",
      dependencies: ["DocURLMapping"]
    ),
    .testTarget(
      name: "SymbolGraphIndexTests",
      dependencies: ["SymbolGraphIndex", "CoreModel"],
      resources: [.copy("Fixtures")]
    ),
  ]
)
