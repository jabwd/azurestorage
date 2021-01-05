// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "BlobstorageSwift",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "BlobstorageSwift",
            targets: ["BlobstorageSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.36.0")
    ],
    targets: [
        .target(
            name: "BlobstorageSwift",
            dependencies: [
                .product(name: "Vapor", package: "vapor")
            ]),
        .testTarget(
            name: "BlobstorageSwiftTests",
            dependencies: [
                "BlobstorageSwift",
                .product(name: "XCTVapor", package: "vapor")
            ]),
    ]
)
