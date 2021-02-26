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
        .package(url: "https://github.com/jabwd/XMLParsing.git", from: "0.0.4"),
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "AzureStorage",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
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
