import Vapor
import AsyncHTTPClient
import NIO
import NIOHTTP1
import Foundation
import XMLParsing

public struct AzureStorage {
    let application: Application
    let configuration: StorageConfiguration
    
    init(_ app: Application) {
        guard let configuration = app.azureStorageConfiguration else {
            fatalError("Azure Storage configuration needs to be configured before using an AzureStorage instance")
        }
        application = app
        self.configuration = configuration
    }

    public func execute(_ method: HTTPMethod, url: URI, body: [UInt8]? = nil, mimeType: String = "application/octet-stream") {
        let headers = HTTPHeaders([
            (AZS.dateHeader, "\(Date().xMSDateFormat)"),
            (AZS.versionHeader, AZS.version),
        ])
        let response = Response(status: .ok, headers: headers)
        response.body = .init(stream: { streamWriter in
        })
//        let req = try! HTTPClient.Request(url: url.description, method: method, headers: headers, body: nil)
//        let resp = application.http.client.shared.execute(request: req, delegate: delegate!).futureResult.map { response -> Void in
//        }
    }

    public func execute(_ method: HTTPMethod, url: URI, body: [UInt8]? = nil, mimeType: String = "application/octet-stream") -> EventLoopFuture<ClientResponse> {
        let headers = HTTPHeaders([
            (AZS.dateHeader, "\(Date().xMSDateFormat)"),
            (AZS.versionHeader, AZS.version),
        ])
        return application.client.send(method, headers: headers, to: url) { req -> () in
            if let body = body {
                req.headers.add(name: "Content-Length", value: "\(body.count)")
                req.headers.add(name: "Content-Type", value: mimeType)
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
