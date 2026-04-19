// swift-tools-version:6.0
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
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.5"),
    ],
    targets: [
        .target(
            name: "Passage",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "LeafKit", package: "leaf-kit"),
                .product(name: "Queues", package: "queues"),
            ],
            resources: [
                .copy("Resources/Views"),
            ]
        ),
        .target(
            name: "PassageOnlyForTest",
            dependencies: [
                "Passage",
            ]
        ),
        .testTarget(
            name: "PassageTests",
            dependencies: [
                "Passage",
                "PassageOnlyForTest",
                .product(name: "VaporTesting", package: "vapor"),
                .product(name: "XCTQueues", package: "queues"),
            ]
        )
    ]
)
