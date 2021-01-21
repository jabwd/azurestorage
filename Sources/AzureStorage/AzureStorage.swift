import Vapor
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

    internal func execute(_ method: HTTPMethod, url: URI, body: [UInt8]? = nil, mimeType: String = "application/octet-stream") -> EventLoopFuture<ClientResponse> {
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

    public func listContainers() -> EventLoopFuture<[Container]> {
        let url = URI(string: "\(configuration.blobEndpoint.absoluteString)/?comp=list")
        return execute(.GET, url: url).map { response -> [Container] in
            guard var body = response.body else {
                return []
            }
            let readableBytes = body.readableBytes
            let data = body.readData(length: readableBytes) ?? Data()
            let decoder = XMLDecoder()
            do {
                let response = try decoder.decode(ContainersEnumerationResultsEntity.self, from: data)
                let containers = response.containers.list.map { Container($0) }
                return containers
            } catch {
                print("Error: \(error)")
            }
            return []
        }
    }

    public func listBlobs(_ name: String) -> EventLoopFuture<[Blob]> {
        let endpoint = "/\(name)?restype=container&comp=list"
        let url = URI(string: "\(configuration.blobEndpoint.absoluteString)\(endpoint)")
        return execute(.GET, url: url).map { response -> [Blob] in
            guard var body = response.body else {
                return []
            }
            let readableBytes = body.readableBytes
            let data = body.readData(length: readableBytes) ?? Data()
            let decoder = XMLDecoder()
            do {
                let response = try decoder.decode(BlobsEnumerationResultsEntity.self, from: data)
                let blobs = response.blobs.list.map { Blob($0) }
                return blobs
            } catch {
                print("Error: \(error)")
            }
            return []
        }
    }

    public func listBlobs(_ container: Container) -> EventLoopFuture<[Blob]> {
        listBlobs(container.name)
    }

    public func readBlob(_ containerName: String, blobName: String) -> EventLoopFuture<ClientResponse> {
        let endpoint = "/\(containerName)/\(blobName)"
        let url = URI(string: "\(configuration.blobEndpoint.absoluteString)\(endpoint)")
        return execute(.GET, url: url)
    }

    public func deleteBlob(_ containerName: String, blobName: String) -> EventLoopFuture<Bool> {
        let endpoint = "/\(containerName)/\(blobName)"
        let url = URI(string: "\(configuration.blobEndpoint.absoluteString)\(endpoint)")
        return execute(.DELETE, url: url).map { response -> Bool in
            response.status == .accepted
        }
    }

    public func putBlock(_ containerName: String, blobName: String, data: [UInt8], mimeType: String) -> EventLoopFuture<String?> {
        guard let blockID = Data.random(bytes: 16)?.base64EncodedString() else {
            return application.eventLoopGroup.future(error: StorageError.randomBytesExhausted)
        }
        guard let encodedID = blockID.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics) else {
            return application.eventLoopGroup.future(error: Abort(.internalServerError))
        }
        let endpoint = "/\(containerName)/\(blobName)?comp=block&blockid=\(encodedID)"
        let url = URI(string: "\(configuration.blobEndpoint.absoluteString)\(endpoint)")
        return execute(.PUT, url: url, body: data, mimeType: mimeType).map { response -> String? in
            if (response.status != .created) {
                return nil
            }
            return blockID
        }
    }

    public func putBlockList(_ containerName: String, blobName: String, list: [String], mimeType: String) -> EventLoopFuture<ClientResponse> {
        let entity = BlockListEntity(blockIDs: list)
        let encoder = XMLEncoder()
        guard let data = try? encoder.encode(entity, withRootKey: "BlockList") else {
            return application.eventLoopGroup.future(error: Abort(.internalServerError))
        }
        let endpoint = "/\(containerName)/\(blobName)?comp=blocklist"
        let url = URI(string: "\(configuration.blobEndpoint.absoluteString)\(endpoint)")
        return execute(.PUT, url: url, body: Array(data), mimeType: mimeType).map { response -> ClientResponse in
            response
        }
    }
}

public extension Application {
    var azureStorage: AzureStorage { .init(self) }
}
