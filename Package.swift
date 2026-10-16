// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LiveCommentKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "LiveCommentKit",
            targets: ["LiveCommentKit"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-collections.git",
            exact: "1.1.6"
        ),
    ],
    targets: [
        .target(
            name: "LiveCommentKit",
            dependencies: [
                .product(name: "DequeModule", package: "swift-collections"),
            ]
        ),
        .testTarget(
            name: "LiveCommentKitTests",
            dependencies: ["LiveCommentKit"]
        ),
    ]
)
