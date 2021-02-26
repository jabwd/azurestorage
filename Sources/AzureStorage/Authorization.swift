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

public struct StorageAuthorization {
    let method: HTTPMethod
    let headers: HTTPHeaders
    let url: URI
    let configuration: StorageConfiguration

    public init(_ method: HTTPMethod, headers: HTTPHeaders, url: URI, config: StorageConfiguration) {
        self.method = method
        self.headers = headers
        self.url = url
        self.configuration = config
    }

    var signature: String {
        return generateSignature(self.method, headers: self.headers, uri: self.url, configuration: self.configuration)
    }

    public var headerValue: String {
        return "SharedKey \(configuration.accountName):\(signature)"
    }
}

fileprivate func generateSignature(
    _ method: HTTPMethod,
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

    // TODO: I probably have to remove percent encoding from the path variable here?
    stringToSign.append("/\(configuration.accountName)\(uri.path)")
    if let params = uri.query?.queryParameters {
        let sortedParams = params.sorted { (lh, rh) -> Bool in
            lh.key.compare(rh.key) == .orderedAscending
        }
        for param in sortedParams {
            guard let value = param.value.removingPercentEncoding else {
                continue
            }
            stringToSign.append("\n\(param.key):\(value)")
        }
    }
    let key = SymmetricKey(data: Data(base64Encoded: configuration.sharedKey)!)
    return Data(HMAC<SHA256>.authenticationCode(for: stringToSign.data(using: .utf8)!, using: key)).base64EncodedString()
}
