// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "AzureStorage",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "AzureStorage",
            targets: ["AzureStorage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.36.0"),
        .package(url: "https://github.com/ShawnMoore/XMLParsing.git", from: "0.0.3")
    ],
    targets: [
        .target(
            name: "AzureStorage",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "XMLParsing", package: "XMLParsing"),
            ]),
        .testTarget(
            name: "BlobstorageSwiftTests",
            dependencies: [
                "AzureStorage",
                .product(name: "XCTVapor", package: "vapor")
            ]),
    ]
)
