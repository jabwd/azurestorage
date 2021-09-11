import XCTest
import XCTVapor
import Vapor
@testable import AzureStorage

extension StorageConfiguration {
  static var developmentConfiguration: StorageConfiguration {
    StorageConfiguration(
      accountName: "devstoreaccount1",
      sharedKey: "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==",
      useHttps: false,
      blobEndpoint: URL(string: "http://127.0.0.1:10000/devstoreaccount1")!,
      queueEndpoint: URL(string: "http://127.0.0.1:10001/devstoreaccount1")!,
      tableEndpoint: URL(string: "http://127.0.0.1:10001/devstoreaccount1")!
    )
  }
}

final class BlobstorageSwiftTests: XCTestCase {
  let app: Application = Application(.testing)

  override func setUp() {
    app.azureStorageConfiguration = .developmentConfiguration
  }

  override func tearDown() {
    app.shutdown()
  }

  func testContainerName() {
    let hyphenBothEnds = "-StartHyphenEnd-"
    let upperCase = "UpperCaseName"
    let doubleHyphen = "test--lol"
    let hyphenEnd = "test-"
    let hyphenStart = "-test"

    let invalidCharacters: [String] = [
      "test@bla",
      "foo bar",
      "foobar!",
      "Testing-(lol)"
    ]

    XCTAssertNil(ContainerName(hyphenBothEnds), "Hyphen both ends should not be allowed")
    XCTAssertEqual(ContainerName(upperCase)?.value, "uppercasename")
    XCTAssertNil(ContainerName(doubleHyphen), "Double hyphen should not be allowed")
    XCTAssertNil(ContainerName(hyphenEnd), "Hyphen start end not allowed")
    XCTAssertNil(ContainerName(hyphenStart), "Hyphen start end not allowed")

    for invalidName in invalidCharacters {
      XCTAssertNil(ContainerName(invalidName), "\(invalidName) should not be allowed")
    }
  }

  func testDecodeConnectionString() {
    let test = "DefaultEndpointsProtocol=https;AccountName=storage;AccountKey=LolSomeKeyXDDDD==;EndpointSuffix=core.windows.net"
    do {
      let config = try StorageConfiguration(test)
      XCTAssert(config.useHttps, "UseHTTPS parsed wrongly")
      XCTAssert(config.accountName == "storage", "Account name not parsed properly, got: \(config.accountName)")
      XCTAssert(config.sharedKey == "LolSomeKeyXDDDD==", "Account key parsed wrongly, got: \(config.sharedKey)")
      XCTAssert(config.blobEndpoint.absoluteString.hasSuffix("core.windows.net"), "Endpoint not constructed correctly, got \(config.blobEndpoint.absoluteString)")

      let devConfig = try StorageConfiguration("UseDevelopmentStorage=true")
      XCTAssert(devConfig == StorageConfiguration.developmentConfiguration, "UseDevelopmentStorage=true not handled")
    } catch {
      XCTAssert(false, "\(error)")
    }
  }

  static var allTests = [
    ("testDecodeConnectionString", testDecodeConnectionString),
  ]
}
