import XCTest
import XCTVapor
import Vapor
@testable import VaporAzs
@testable import AzureStorage

final class AzureStorageTests: XCTestCase {
  let app: Application = Application(.testing)

  override func setUp() {
    app.azureStorageConfiguration = AzureStorage.Configuration()
  }

  override func tearDown() {
    try? FileManager.default.removeItem(atPath: "/tmp/bigbucksmoll.mp4")
    app.shutdown()
  }

  func testDecodeConnectionString() {
    let test = "DefaultEndpointsProtocol=https;AccountName=storage;AccountKey=LolSomeKeyXDDDD==;EndpointSuffix=core.windows.net"
    do {
      let config = try AzureStorage.Configuration(test)
      XCTAssert(config.useHttps, "UseHTTPS parsed wrongly")
      XCTAssert(config.accountName == "storage", "Account name not parsed properly, got: \(config.accountName)")
      XCTAssert(config.sharedKey == "LolSomeKeyXDDDD==", "Account key parsed wrongly, got: \(config.sharedKey)")
      XCTAssert(config.blobEndpoint.absoluteString.hasSuffix("core.windows.net"), "Endpoint not constructed correctly, got \(config.blobEndpoint.absoluteString)")

      let devConfig = try AzureStorage.Configuration("UseDevelopmentStorage=true")
      XCTAssert(devConfig == AzureStorage.Configuration(), "UseDevelopmentStorage=true not handled")
    } catch {
      XCTAssert(false, "\(error)")
    }
  }

  func testContainers() throws {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }

    let container1 = "azurestoragetest1"
    let container2 = "azurestoragetest2"

    let eventLoop = eventLoopGroup.next()

    // Stages:
    // 1. - Create 2 containers: azurestoragetest1, azurestoragetest2
    // 2. - List containers, verify azurestoragetest1, azurestoragetest2 exist in the list (more con exist, using local dev azurite)
    // 3. - Delete containers azurestoragetest1, azurestoragetest2
    // 4. - List containers again, verify azurestoragetest1, azurestoragetest2 are gone

    let storage = AzureStorage(config: .init(), eventLoopGroupProvider: .shared(eventLoopGroup))
    let create1Promise = storage.container.createIfNotExists(container1, on: eventLoop)
    let create2Promise = storage.container.createIfNotExists(container2, on: eventLoop)
    let result = [create1Promise, create2Promise].flatten(on: eventLoop).flatMap { _ -> EventLoopFuture<Void> in
      return storage.container.listContainers(on: eventLoop).flatMap { list in
        XCTAssert(list.contains(where: { $0.name.value == container1 }))
        XCTAssert(list.contains(where: { $0.name.value == container2 }))
        return eventLoop.makeSucceededVoidFuture()
      }
    }
    .flatMap { _ -> EventLoopFuture<Void> in
      let delete1Promise = storage.container.delete(container1, on: eventLoop)
      let delete2Promise = storage.container.delete(container2, on: eventLoop)
      return [delete1Promise, delete2Promise].flatten(on: eventLoop).flatMap { _ in
        return storage.container.listContainers(on: eventLoop).flatMap { list in
          XCTAssertFalse(list.contains(where: { $0.name.value == container1 }))
          XCTAssertFalse(list.contains(where: { $0.name.value == container2 }))
          return eventLoop.makeSucceededVoidFuture()
        }
      }
    }
    try result.wait()
    try storage.shutDown()
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

  func testBlobs() throws {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    defer { XCTAssertNoThrow(try eventLoopGroup.syncShutdownGracefully()) }

    let container1 = "azurestoragetest1"

    let eventLoop = eventLoopGroup.next()

    guard let file = Bundle.module.url(forResource: "bigbucksmoll", withExtension: "mp4") else {
      XCTAssert(false, "File bigbucksmoll.mp4 not found")
      return
    }
    let pool = NIOThreadPool(numberOfThreads: 1)
    pool.start()
    defer { XCTAssertNoThrow(try pool.syncShutdownGracefully()) }
    let fileIO = NonBlockingFileIO(threadPool: pool)
    let fileData = try Data(contentsOf: file)
    let buffer = ByteBuffer.init(data: fileData)
    let storage = AzureStorage(config: .init(), eventLoopGroupProvider: .shared(eventLoopGroup))
    let create = storage.container.createIfNotExists(container1, on: eventLoop)

    let result = create.flatMap { _ -> EventLoopFuture<String?> in
      do {
        return try storage.blob.uploadBlock(container1, blob: "bigbucksmoll.mp4", buffer: buffer, on: eventLoop)
      } catch {
        return eventLoop.makeFailedFuture(error)
      }
    }.unwrap(or: StorageError.invalidBlobID)
      .flatMap { blockID -> EventLoopFuture<HTTPClient.Response> in
        do {
          return try storage.blob.finalize(container1, blobName: "bigbucksmoll.mp4", list: [blockID], on: eventLoop)
        } catch {
          return eventLoop.makeFailedFuture(error)
        }
      }
      .flatMap { response -> EventLoopFuture<Void> in
        do {
          return try storage.blob.downloadTo(filePath: "/tmp/bigbucksmoll.mp4", container: container1, blob: "bigbucksmoll.mp4", fileio: fileIO, on: eventLoop)
        } catch {
          return eventLoop.makeFailedFuture(error)
        }
      }
      .flatMap({ _ -> EventLoopFuture<Bool> in
        do {
          return try storage.blob.delete(container1, blobName: "bigbucksmoll.mp4", on: eventLoop)
        } catch {
          return eventLoop.makeFailedFuture(error)
        }
      })
      .map { _ in
        XCTAssert(FileManager.default.fileExists(atPath: "/tmp/bigbucksmoll.mp4"))
      }
      .always { result in
        switch result {
        case .success():
          break
        case .failure(let error):
          XCTAssert(false, "\(error)")
        }
      }

    try result.wait()
    try storage.shutDown()
  }

  func upload(_ storage: AzureStorage, eventLoop: EventLoop) {

  }

  static var allTests = [
    ("testDecodeConnectionString", testDecodeConnectionString),
    ("testContainerName", testContainerName),
    ("testContainers", testContainers),
    ("testBlobs", testBlobs)
  ]
}
