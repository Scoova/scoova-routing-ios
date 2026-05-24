// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScoovaRouting",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .library(name: "ScoovaRouting", targets: ["ScoovaRouting"]),
    ],
    targets: [
        .target(name: "ScoovaRouting", path: "Sources/ScoovaRouting"),
        .testTarget(name: "ScoovaRoutingTests", dependencies: ["ScoovaRouting"], path: "Tests/ScoovaRoutingTests"),
    ]
)
