import AsyncHTTPClient
import NIO
import NIOHTTP1
import Foundation
import XMLParsing
import Logging

public struct AzureStorage {
  public let config: Configuration
  public let httpClient: HTTPClient
  public let logger = Logger(label: "azurestorage")

  public init(config: Configuration, eventLoopGroupProvider: HTTPClient.EventLoopGroupProvider = .createNew) {
    self.config = config
    self.httpClient = HTTPClient(eventLoopGroupProvider: eventLoopGroupProvider)
  }

  public func shutDown() throws {
    try self.httpClient.syncShutdown()
  }

  // MARK: -

  public func execute(_ method: HTTPMethod, url: URL, body: ByteBuffer? = nil) throws -> EventLoopFuture<HTTPClient.Response> {
    var headers = HTTPHeaders.defaultAzureStorageHeaders
    var request = try HTTPClient.Request(url: url, method: method)
    if let body = body {
      headers.add(name: "Content-Length", value: "\(body.readableBytes)")
      headers.add(name: "Content-Type", value: "application/octet-stream")
      request.body = .byteBuffer(body)
    }
    headers.authorizeFor(method: method, url: url, config: config)
    request.headers = headers
    return httpClient.execute(request: request)
  }

  public func execute(_ method: HTTPMethod, url: URL, body: [UInt8]?) throws -> EventLoopFuture<HTTPClient.Response> {
    if let body = body {
      return try execute(method, url: url, body: ByteBuffer(bytes: body))
    }
    return try execute(method, url: url)
  }

  public func blobEndpoint(_ endpoint: String) -> URL {
    URL(string: "\(config.blobEndpoint.absoluteString)/\(endpoint)")!
  }

  public var blob: BlobService {
    BlobService(self)
  }

  public var container: ContainerService {
    ContainerService(self)
  }
}
