//
//  Signature.swift
//  
//
//  Created by Antwan van Houdt on 14/01/2021.
//
//  Helper functions for generating a valid Authorization signature
//  string for azure storage using a shared key

import Vapor

extension String {
    mutating func appendWithNewLine(_ str: String?) {
        guard let str = str else {
            self.append("\n")
            return
        }
        self.append("\(str)\n")
    }

    var queryParameters: [(key: String, value: String)] {
        let components = self.split(separator: "&")
        var result: [(key: String, value: String)] = []
        for component in components {
            let separatorIdx = component.firstIndex { $0 == "=" }
            guard let idx = separatorIdx else {
                continue
            }
            let key = String(component[component.startIndex..<idx])
            let value = String(component[component.index(after: idx)..<component.endIndex])
            result.append((key, value))
        }
        return result
    }
}

struct StorageAuthorization {
    let method: HTTPMethod
    let headers: HTTPHeaders
    let queryParams: [(String, String)]
    let url: URI
    let configuration: StorageConfiguration

    init(_ method: HTTPMethod, headers: HTTPHeaders, queryParams: [(String, String)], url: URI, config: StorageConfiguration) {
        self.method = method
        self.headers = headers
        self.queryParams = queryParams
        self.url = url
        self.configuration = config
    }

    
    var signature: String {
        return generateSignature(self.method, headers: self.headers, queryParams: self.queryParams, uri: self.url, configuration: self.configuration)
    }

    var headerValue: String {
        return "SharedKey \(configuration.accountName):\(signature)"
    }
}

fileprivate func generateSignature(
    _ method: HTTPMethod,
    headers: HTTPHeaders,
    queryParams: [(String, String)] = [],
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
    /* if let params = uri.query?.queryParameters {
        let sortedParams = params.sorted { (lh, rh) -> Bool in
            lh.key.compare(rh.key) == .orderedAscending
        }
        for param in sortedParams {
            stringToSign.append("\n\(param.key):\(param.value)")
        }
    } */
    if queryParams.count > 0 {
        let sortedParams = queryParams.sorted { (lh, rh) -> Bool in
            lh.0.compare(rh.0) == .orderedAscending
        }
        for param in sortedParams {
            stringToSign.append("\n\(param.0):\(param.1)")
        }
    }
    print("String to sign:\n\(stringToSign)")
    print("end")
    let key = SymmetricKey(data: Data(base64Encoded: configuration.sharedKey)!)
    return Data(HMAC<SHA256>.authenticationCode(for: stringToSign.data(using: .utf8)!, using: key)).base64EncodedString()
}

public extension CharacterSet {
    static let urlQueryParameterAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&?"))

    static let urlQueryDenied           = CharacterSet.urlQueryAllowed.inverted()
    static let urlQueryKeyValueDenied   = CharacterSet.urlQueryParameterAllowed.inverted()
    static let urlPathDenied            = CharacterSet.urlPathAllowed.inverted()
    static let urlFragmentDenied        = CharacterSet.urlFragmentAllowed.inverted()
    static let urlHostDenied            = CharacterSet.urlHostAllowed.inverted()

    static let urlDenied                = CharacterSet.urlQueryDenied
        .union(.urlQueryKeyValueDenied)
        .union(.urlPathDenied)
        .union(.urlFragmentDenied)
        .union(.urlHostDenied)


    func inverted() -> CharacterSet {
        var copy = self
        copy.invert()
        return copy
    }
}



public extension String {
    func urlEncoded(denying deniedCharacters: CharacterSet = .urlDenied) -> String? {
        return addingPercentEncoding(withAllowedCharacters: deniedCharacters.inverted())
    }
}
