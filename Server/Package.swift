// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SettleServer",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "SettleServer", targets: ["SettleServer"])
    ],
    dependencies: [
        .package(path: "../Packages/SettleCore"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.28.0"),
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.14.3"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.13.3"),
        .package(url: "https://github.com/swift-server/swift-openapi-hummingbird.git", from: "2.1.0"),
    ],
    targets: [
        .target(
            name: "SettleAPI",
            dependencies: [
                .product(name: "SettleCore", package: "SettleCore"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIHummingbird", package: "swift-openapi-hummingbird"),
            ],
            plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]
        ),
        .executableTarget(
            name: "SettleServer",
            dependencies: ["SettleAPI"]
        ),
        .testTarget(
            name: "SettleAPITests",
            dependencies: [
                "SettleAPI",
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ]
        ),
    ]
)
