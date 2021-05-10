import Vapor
import AsyncHTTPClient
import NIO
import NIOHTTP1
import Foundation
import XMLParsing

public struct AzureStorage {
  /// The version of AZS to use, this version has been tested with this code
  /// and seems to work well for now. Any earlier versions could break on assumptions made elsewhere
  public static let version: String = "2019-07-07"

  /// The prefix used for all canonical headers meant for the Azure Storage API `x-ms-{HEADER}`
  public static let canonicalPrefix = "x-ms"

  /// The date header value needs to be within 15 minutes of the current time of the request being
  /// handled by the blobstorage server
  public static let dateHeader = "x-ms-date"

  /// This header indicates some specific quirks on the protocol itself, this project currently
  /// only aims to be compatible with the latest few versions
  public static let versionHeader = "x-ms-version"

  public let logger = Logger(label: "azurestorage")

  let configuration: StorageConfiguration

  init(_ app: Application) {
    guard let configuration = app.azureStorageConfiguration else {
      fatalError("Azure Storage configuration needs to be configured before using an AzureStorage instance")
    }
    self.configuration = configuration
  }

  public func execute(_ method: HTTPMethod, url: URI, body: ByteBuffer? = nil, on client: Client) -> EventLoopFuture<ClientResponse> {
    let headers = HTTPHeaders([
      (AzureStorage.dateHeader, "\(Date().xMSDateFormat)"),
      (AzureStorage.versionHeader, AzureStorage.version),
    ])
    return client.send(method, headers: headers, to: url) { req -> () in
      if let body = body {
        req.headers.add(name: "Content-Length", value: "\(body.readableBytes)")
        // The content type can probably be removed, I haven't tested this thoroughly
        // but azure seems to ignore this header alltogether
        // and setting the content-type semes to be an action done after the fact
        // I have observed similar behaviour in the .NET implementation of AZS
        // where it ignores this header alltogether and just executes 2 api calls to perform this action
        req.headers.add(name: "Content-Type", value: "application/octet-stream")
        req.body = body
      }
      let authorization = StorageAuthorization(method, headers: req.headers, url: url, config: configuration)
      req.headers.add(name: "Authorization", value: authorization.headerValue)
    }
  }

  public func execute(_ method: HTTPMethod, url: URI, body: [UInt8]?, on client: Client) -> EventLoopFuture<ClientResponse> {
    if let body = body {
      return execute(method, url: url, body: ByteBuffer(bytes: body), on: client)
    }
    return execute(method, url: url, on: client)
  }
}

public extension Application {
  var azureStorage: AzureStorage { .init(self) }
  var blobStorage: BlobService { BlobService(azureStorage) }
  var blobContainers: ContainerService { ContainerService(azureStorage) }
}
