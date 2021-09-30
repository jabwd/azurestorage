import XCTest
import XCTVapor
import Vapor
@testable import AzureStorage

final class BlobstorageSwiftTests: XCTestCase {
  let app: Application = Application(.testing)

  override func setUp() {
    app.azureStorageConfiguration = AzureStorage.Configuration()
  }

  override func tearDown() {
    app.shutdown()
  }

  //    func testDecodeConnectionString() {
  //        let test = "DefaultEndpointsProtocol=https;AccountName=storage;AccountKey=LolSomeKeyXDDDD==;EndpointSuffix=core.windows.net"
  //        do {
  //            let config = try StorageConfiguration(test)
  //            XCTAssert(config.useHttps, "UseHTTPS parsed wrongly")
  //            XCTAssert(config.accountName == "storage", "Account name not parsed properly, got: \(config.accountName)")
  //            XCTAssert(config.sharedKey == "LolSomeKeyXDDDD==", "Account key parsed wrongly, got: \(config.sharedKey)")
  //            XCTAssert(config.blobEndpoint.absoluteString.hasSuffix("core.windows.net"), "Endpoint not constructed correctly, got \(config.blobEndpoint.absoluteString)")
  //
  //            let devConfig = try StorageConfiguration("UseDevelopmentStorage=true")
  //            XCTAssert(devConfig == StorageConfiguration.developmentConfiguration, "UseDevelopmentStorage=true not handled")
  //        } catch {
  //            XCTAssert(false, "\(error)")
  //        }
  //    }
  //
  //    func testCreateContainer() {
  //
  //    }
  //
  //    func testListContainers() {
  //        let group = DispatchGroup()
  //        group.enter()
  //
  //        _ = app.azureStorage.listContainers().map { res in
  //            print("Containers: \(res)")
  //            group.leave()
  //        }
  //        group.wait()
  //    }
  //
  //    func testDeleteContainer() {
  //
  //    }
  //
  //    func testListBlobs() {
  //        let group = DispatchGroup()
  //        group.enter()
  //
  //        _ = app.azureStorage.listBlobs("videofiles").map { res in
  //            print("Blobs: \(res)")
  //            group.leave()
  //        }
  //        group.wait()
  //    }

  func testBlobs() {

//    let group = DispatchGroup()
//    group.enter()
//
//    let data = try! Data(contentsOf: URL(string: "file:///Users/jabwd/Developer/Triple/AzureStorage/README.md")!)
//    let buff = Array(data)
//    let blobName = "\(UUID().uuidString).md"
//    let blockFuture = app.blobStorage.uploadBlock("test", blobName: blobName, data: buff, on: app.client).map { res -> String in
//      guard let blockID = res else {
//        XCTAssert(false, "Did not receive a blockID")
//        group.leave()
//        return ""
//      }
//      return blockID
//    }
//
//    _ = blockFuture.map { blockID -> () in
//      let list = [blockID]
//      _ = self.app.blobStorage.finalize("test", blobName: blobName, list: list, on: self.app.client).map { (response) -> () in
//        print("AZS Response: \(response)")
//      }
//      group.leave()
//    }
//
//    group.wait()
  }

  static var allTests = [
    //        ("testDecodeConnectionString", testDecodeConnectionString),
    //        ("testListContainers", testListContainers),
    //        ("testDeleteContainer", testDeleteContainer),
    //        ("testListBlobs", testListBlobs),
    ("testBlobs", testBlobs),
  ]
}
