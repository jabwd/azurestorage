import XCTest
import XCTVapor
@testable import BlobstorageSwift

final class BlobstorageSwiftTests: XCTestCase {
    let app: Application = Application(.testing)

    override func setUp() {
    }

    override func tearDown() {
        app.shutdown()
    }
    
    func testListContainers() {
    }

    static var allTests = [
        ("testListContainers", testListContainers),
    ]
}
