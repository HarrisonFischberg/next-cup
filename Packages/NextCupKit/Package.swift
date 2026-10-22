// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "NextCupKit",
  platforms: [.iOS("27.0"), .macOS(.v15)],
  products: [
    .library(name: "NextCupKit", targets: ["NextCupKit"])
  ],
  targets: [
    .target(
      name: "NextCupKit",
      swiftSettings: [.unsafeFlags(["-warnings-as-errors"])]
    ),
    .testTarget(
      name: "NextCupKitTests",
      dependencies: ["NextCupKit"]
    ),
  ]
)
