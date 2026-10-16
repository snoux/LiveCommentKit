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
        .package(
            url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git",
            from: "3.1.4"
        ),
        .package(
            url: "https://github.com/SDWebImage/SDWebImage.git",
            from: "5.21.1"
        ),
    ],
    targets: [
        .target(
            name: "LiveCommentKit",
            dependencies: [
                .product(name: "DequeModule", package: "swift-collections"),
                .product(name: "SDWebImageSwiftUI", package: "SDWebImageSwiftUI"),
                .product(name: "SDWebImage", package: "SDWebImage"),
            ]
        ),
        .testTarget(
            name: "LiveCommentKitTests",
            dependencies: ["LiveCommentKit"]
        ),
    ]
)
