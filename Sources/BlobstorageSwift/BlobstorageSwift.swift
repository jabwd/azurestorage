import Vapor

struct StorageConfiguration {
    let connectionString: String
    let useEmulator: Bool
}

public enum KeyType: String {
    case sharedKey = "SharedKey"
    case sharedKeyLite = "SharedKeyLite"
}

public struct Blobstorage {
    let application: Application
    
    init(_ app: Application) {
        application = app
    }
    
    static func generateAuthorizationHeader(
        httpMethod: HTTPMethod,
        timestamp: Int,
        key: String,
        keyType: KeyType = .sharedKey
    ) -> String {
        /*
         StringToSign = VERB + "\n" +
         Content-Encoding + "\n" +
         Content-Language + "\n" +
         Content-Length + "\n" +
         Content-MD5 + "\n" +
         Content-Type + "\n" +
         Date + "\n" +
         If-Modified-Since + "\n" +
         If-Match + "\n" +
         If-None-Match + "\n" +
         If-Unmodified-Since + "\n" +
         Range + "\n" +
         CanonicalizedHeaders +
         CanonicalizedResource;
         */
        var stringToSign = "\(httpMethod.rawValue.uppercased())\n"
        var components: [String] = [
            httpMethod.string,
            
        ]
        return ""
    }
}

extension Application {
    public var blobstorage: Blobstorage { .init(self) }
}
