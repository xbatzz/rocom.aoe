// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "RocoContent",
    platforms: [.iOS(.v27), .macOS(.v15)],
    products: [
        .library(name: "RocoContent", targets: ["RocoContent"]),
        .library(name: "RocoUserData", targets: ["RocoUserData"]),
        .executable(name: "content-probe", targets: ["ContentProbe"])
    ],
    dependencies: [.package(path: "../RocoCore")],
    targets: [
        .target(name: "RocoContent", dependencies: [.product(name: "RocoDomain", package: "RocoCore")],
            swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]),
        .executableTarget(name: "ContentProbe", dependencies: ["RocoContent"]),
        .testTarget(name: "RocoContentTests", dependencies: ["RocoContent"]),
        .target(name: "RocoUserData"),
        .testTarget(name: "RocoUserDataTests", dependencies: ["RocoUserData"])
    ],
    swiftLanguageModes: [.v6]
)
