import Vapor
import Foundation

public struct Blobstorage {
    let application: Application
    
    init(_ app: Application) {
        application = app
    }
    
    static func generateSignature(
        method: HTTPMethod,
        headers: HTTPHeaders,
        uri: URI,
        configuration: StorageConfiguration
    ) -> String {
        var canonicalizedHeaders: [(String, String)] = []
        for header in headers {
            if (header.name.hasPrefix("x-ms")) {
                canonicalizedHeaders.append(header)
                continue
            }
        }
        canonicalizedHeaders = canonicalizedHeaders.sorted(by: { (lh, rh) -> Bool in
            lh.0.caseInsensitiveCompare(rh.0) == ComparisonResult.orderedAscending
        })

        var stringToSign = "\(method)\n"
        stringToSign.appendWithNewLine(headers.first(name: "Content-Encoding"))
        stringToSign.appendWithNewLine(headers.first(name: "Content-Language"))
        stringToSign.appendWithNewLine(headers.first(name: "Content-Length"))
        stringToSign.appendWithNewLine(headers.first(name: "Content-MD5"))
        stringToSign.appendWithNewLine(headers.first(name: "Content-Type"))
        stringToSign.appendWithNewLine(nil) // Date, we use x-ms-date instead.
        stringToSign.appendWithNewLine(headers.first(name: "If-Modified-Since"))
        stringToSign.appendWithNewLine(headers.first(name: "If-Match"))
        stringToSign.appendWithNewLine(headers.first(name: "If-None-Match"))
        stringToSign.appendWithNewLine(headers.first(name: "If-Unmodified-Since"))
        stringToSign.appendWithNewLine(headers.first(name: "Range"))

        for header in canonicalizedHeaders {
            stringToSign.appendWithNewLine("\(header.0.lowercased()):\(header.1)")
        }

        stringToSign.append("/\(configuration.accountName)\(uri.path)")
        if let params = uri.query?.queryParameters {
            for param in params {
                stringToSign.append("\n\(param.key):\(param.value)")
            }
        }
        let key = SymmetricKey(data: Data(base64Encoded: configuration.sharedKey)!)
        return Data(HMAC<SHA256>.authenticationCode(for: stringToSign.data(using: .utf8)!, using: key)).base64EncodedString()
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
            return self.application.client.get(url, headers: headers) { req -> () in
                let signature = Blobstorage.generateSignature(method: .GET, headers: req.headers, uri: req.url, configuration: config)
                req.headers.add(name: "Authorization", value: "SharedKey devstoreaccount1:\(signature)")
                print("Request: \(req.headers)")
            }
        }
    }

    public func listContainerContents() {
        
    }
}

public extension Application {
    var blobstorage: Blobstorage { .init(self) }
}
