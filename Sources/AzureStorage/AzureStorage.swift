import Vapor
import AsyncHTTPClient
import NIO
import NIOHTTP1
import Foundation
import XMLParsing

public struct AzureStorage {
  let configuration: StorageConfiguration

  init(_ app: Application) {
    guard let configuration = app.azureStorageConfiguration else {
      fatalError("Azure Storage configuration needs to be configured before using an AzureStorage instance")
    }
    self.configuration = configuration
  }

  public func execute(_ method: HTTPMethod, url: URI, body: [UInt8]? = nil, on client: Client) -> EventLoopFuture<ClientResponse> {
    let headers = HTTPHeaders([
      (AZS.dateHeader, "\(Date().xMSDateFormat)"),
      (AZS.versionHeader, AZS.version),
    ])
    return client.send(method, headers: headers, to: url) { req -> () in
      if let body = body {
        req.headers.add(name: "Content-Length", value: "\(body.count)")
        // The content type can probably be removed, I haven't tested this thoroughly
        // but azure seems to ignore this header alltogether
        // and setting the content-type semes to be an action done after the fact
        // I have observed similar behaviour in the .NET implementation of AZS
        // where it ignores this header alltogether and just executes 2 api calls to perform this action
        req.headers.add(name: "Content-Type", value: "application/octet-stream")
        req.body = ByteBuffer(bytes: body)
      }
      let authorization = StorageAuthorization(method, headers: req.headers, url: url, config: configuration)
      req.headers.add(name: "Authorization", value: authorization.headerValue)
    }
  }
}

public extension Application {
  var azureStorage: AzureStorage { .init(self) }
  var blobStorage: BlobService { BlobService(azureStorage) }
  var blobContainers: ContainerService { ContainerService(azureStorage) }
}
