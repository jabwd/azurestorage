import Vapor
import Foundation

public struct AzureStorage {
    let application: Application
    
    init(_ app: Application) {
        application = app
    }

    public func listContainers() -> EventLoopFuture<ClientResponse> {
        let config = try! StorageConfiguration.init("UseDevelopmentStorage=true")
        return application.eventLoopGroup.future().flatMap { _ -> EventLoopFuture<ClientResponse> in
            let url = URI(string: "http://localhost:10000/devstoreaccount1/?comp=list")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = ""
            let headers = HTTPHeaders([
                ("x-ms-date", "\(Date().xMSDateFormat)"),
                ("x-ms-version", Constants.version),
            ])
            let authorization = StorageAuthorization(.GET, headers: headers, url: url, config: config)
            return self.application.client.get(url, headers: headers) { req -> () in
                req.headers.add(name: "Authorization", value: authorization.headerValue)
                print("Request: \(req.headers)")
            }
        }
    }

    public func listContainerContents() {
        
    }
}

public extension Application {
    var azureStorage: AzureStorage { .init(self) }
}
