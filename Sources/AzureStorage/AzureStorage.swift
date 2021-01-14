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

    internal func get(_ url: URI) -> EventLoopFuture<ClientResponse> {
        return application.eventLoopGroup.future().flatMap { _ -> EventLoopFuture<ClientResponse> in
            let headers = HTTPHeaders([
                (AZS.dateHeader, "\(Date().xMSDateFormat)"),
                (AZS.versionHeader, AZS.version),
            ])
            let authorization = StorageAuthorization(.GET, headers: headers, url: url, config: configuration)
            return self.application.client.get(url, headers: headers) { req -> () in
                req.headers.add(name: "Authorization", value: authorization.headerValue)
            }
        }
    }

    public func listContainers() -> EventLoopFuture<[Container]> {
        let url = URI(string: "\(configuration.blobEndpoint.absoluteString)/?comp=list")
        return get(url).map { response -> [Container] in
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
        return get(url).map { response -> [Blob] in
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

    public func readBlob(_ containerName: String, blobName: String) {
    }

    public func deleteBlob(_ containerName: String, blobName: String) {
    }

    public func putBlob(_ containerName: String, blobName: String) {
    }

    public func listBlobs(_ container: Container) -> EventLoopFuture<[Blob]> {
        listBlobs(container.name)
    }
}

public extension Application {
    var azureStorage: AzureStorage { .init(self) }
}
