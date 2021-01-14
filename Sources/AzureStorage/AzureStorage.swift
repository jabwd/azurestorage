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
        let url = URI(string: "http://localhost:10000/devstoreaccount1/?comp=list")
        return get(url).map { response -> [Container] in
            guard var body = response.body else {
                return []
            }
            let readableBytes = body.readableBytes
            let data = body.readData(length: readableBytes) ?? Data()
            let decoder = XMLDecoder()
            do {
                let response = try decoder.decode(EnumerationResultsEntity.self, from: data)
                let containers = response.containers.list.map { Container($0) }
                print("Response: \(containers)")
            } catch {
                print("Error: \(error)")
            }
            return []
        }
    }

    public func listContainerContents() {
        
    }
}

public extension Application {
    var azureStorage: AzureStorage { .init(self) }
}
