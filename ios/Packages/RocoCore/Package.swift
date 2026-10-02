// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RocoCore",
    platforms: [.iOS(.v27), .macOS(.v15)],
    products: [.library(name: "RocoDomain", targets: ["RocoDomain"])],
    targets: [
        .target(name: "RocoDomain", swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]),
        .testTarget(name: "RocoDomainTests", dependencies: ["RocoDomain"])
    ],
    swiftLanguageModes: [.v6]
)
