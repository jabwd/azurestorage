//
//  HTTPHeaders+AzureStorage.swift
//  
//
//  Created by Antwan van Houdt on 12/05/2021.
//

import NIOHTTP1
import Crypto
import Foundation

public extension HTTPHeaders {

  /// By default all requests need to have a date (in as pecific format)
  /// and version header attached, this static variable provides the default set for most requests
  static var defaultAzureStorageHeaders: HTTPHeaders {
    HTTPHeaders([
      ("x-ms-date", Date().xMSDateFormat),
      ("x-ms-version", "2019-07-07"),
    ])
  }

  mutating func authorizeFor(
    method: HTTPMethod,
    url: URL,
    config: AzureStorage.Configuration
  ) {
    let signature = generateSignature(method, headers: self, url: url, configuration: config)
    self.add(name: "Authorization", value: "SharedKey \(config.accountName):\(signature)")
  }
}

fileprivate func generateSignature(
  _ method: HTTPMethod,
  headers: HTTPHeaders,
  url: URL,
  configuration: AzureStorage.Configuration
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
  stringToSign.append("/\(configuration.accountName)\(url.path)")
  if let params = url.query?.queryParameters {
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
