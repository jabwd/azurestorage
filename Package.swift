// swift-tools-version:5.5
import PackageDescription

let package = Package(
  name: "azurestorage",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .watchOS(.v6),
    .tvOS(.v13),
  ],
  products: [
    .executable(
      name: "azsclient",
      targets: ["azsclient"]
    ),
    .library(
      name: "AzureStorage",
      targets: ["AzureStorage"]),
    .library(
      name: "VaporAzs",
      targets: ["VaporAzs"]
    ),
  ],
  dependencies: [
    .package(name: "swift-nio", url: "https://github.com/apple/swift-nio.git", from: "2.33.0"),
    .package(name: "swift-nio-http2", url: "https://github.com/apple/swift-nio-http2.git", from: "1.13.0"),
    .package(name: "swift-nio-ssl", url: "https://github.com/apple/swift-nio-ssl.git", from: "2.14.1"),
    .package(name: "swift-crypto", url: "https://github.com/apple/swift-crypto.git", from: "1.0.0"),
    .package(name: "async-kit", url: "https://github.com/vapor/async-kit.git", from: "1.0.0"),
    .package(name: "swift-argument-parser", url: "https://github.com/apple/swift-argument-parser", from: "1.0.1"),
    .package(name: "swift-log", url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    .package(name: "vapor", url: "https://github.com/vapor/vapor.git", from: "4.48.7"),
    .package(url: "https://github.com/jabwd/XMLParsing.git", from: "0.0.4"),
    .package(name: "async-http-client", url: "https://github.com/swift-server/async-http-client.git", from: "1.6.0"),

  ],
  targets: [
    .executableTarget(
      name: "azsclient",
      dependencies: [
        "AzureStorage",
        "VaporAzs",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .target(
      name: "AzureStorage",
      dependencies: [
        .product(name: "AsyncKit", package: "async-kit"),
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "NIOFoundationCompat", package: "swift-nio"),
        .product(name: "NIOSSL", package: "swift-nio-ssl"),
        .product(name: "NIOHTTP1", package: "swift-nio"),
        .product(name: "NIOWebSocket", package: "swift-nio"),
        .product(name: "NIOHTTP2", package: "swift-nio-http2"),
        .product(name: "Crypto", package: "swift-crypto"),

        .product(name: "AsyncHTTPClient", package: "async-http-client"),
        .product(name: "XMLParsing", package: "XMLParsing"),
        .product(name: "Logging", package: "swift-log")
      ]),
    .target(
      name: "VaporAzs",
      dependencies: [
        .product(name: "Vapor", package: "vapor"),
        "AzureStorage"
      ]),
    .testTarget(
      name: "AzureStorageTests",
      dependencies: [
        "AzureStorage",
        "VaporAzs",
        .product(name: "XCTVapor", package: "vapor"),
      ], resources: [.process("Fixtures")]),
  ]
)
