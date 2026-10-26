// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SettleCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SettleCore", targets: ["SettleCore"]),
    ],
    targets: [
        .target(name: "SettleCore"),
        .testTarget(
            name: "SettleCoreTests",
            dependencies: ["SettleCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
