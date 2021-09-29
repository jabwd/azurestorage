// swift-tools-version:5.5
import PackageDescription

let package = Package(
  name: "azurestorage",
  platforms: [
    .macOS(.v10_15)
  ],
  products: [
    .executable(
      name: "azsclient",
      targets: ["azsclient"]
    ),
    .library(
      name: "AzureStorage",
      targets: ["AzureStorage"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.1"),
    .package(url: "https://github.com/vapor/vapor.git", from: "4.48.7"),
    .package(url: "https://github.com/jabwd/XMLParsing.git", from: "0.0.4"),
    .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.6.0"),
  ],
  targets: [
    .executableTarget(
      name: "azsclient",
      dependencies: [
        "AzureStorage",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
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
