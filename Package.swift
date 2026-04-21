// swift-tools-version:6.3
import PackageDescription

let package = Package(
    name: "passage",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "Passage", targets: ["Passage"]),
        .library(name: "PassageOnlyForTest", targets: ["PassageOnlyForTest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.121.4"),
        .package(url: "https://github.com/vapor/jwt.git", from: "5.1.2"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.5.1"),
        .package(url: "https://github.com/vapor/leaf-kit.git", from: "1.14.2"),
        .package(url: "https://github.com/vapor/queues.git", from: "1.18.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.12.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.98.0"),
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.4.6"),
    ],
    targets: [
        .target(
            name: "Passage",
            dependencies: [
                .product(name: "JWT", package: "jwt"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "LeafKit", package: "leaf-kit"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "Queues", package: "queues"),
                .product(name: "Vapor", package: "vapor"),
            ],
            resources: [
                .copy("Resources/Views"),
            ],
            swiftSettings: swiftSettings
        ),
        .target(
            name: "PassageOnlyForTest",
            dependencies: [
                "Passage",
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "PassageTests",
            dependencies: [
                .product(name: "VaporTesting", package: "vapor"),
                .product(name: "XCTQueues", package: "queues"),
                "Passage",
                "PassageOnlyForTest",
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("ImmutableWeakCaptures"),
] }
