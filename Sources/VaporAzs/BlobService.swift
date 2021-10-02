//
//  BlobService.swift
//  
//
//  Created by Antwan van Houdt on 01/10/2021.
//

import Vapor
import NIOHTTP1
import AzureStorage

extension BlobService {
  /// Returns a Response object that will be written to asynchronously when new data is available
  /// - Parameters:
  ///   - blob: Blob name to search for
  ///   - container: Container name to search blob in
  ///   - fileName: Filename to add to the response headers in case a different filename is desired
  ///   - req: Vapor.Request object (mostly for creating a HTTPClient instance on the right eventLoop)
  public func stream(
    blob: String,
    container: String,
    fileName: String? = nil,
    headers: HTTPHeaders? = nil,
    with req: Request
  ) throws -> EventLoopFuture<Response> {
    let endpoint = "/\(container)/\(blob)"
    let url = URL(string: "\(storage.config.blobEndpoint.absoluteString)\(endpoint)")!

    var requestHeaders = HTTPHeaders.defaultAzureStorageHeaders

    // Support range header requests, add partialContent status if we only requested a number of bytes
    var status: HTTPStatus = .ok
    if req.headers.contains(name: .range) {
      requestHeaders.replaceOrAdd(name: .range, value: req.headers.first(name: .range) ?? "")
      status = .partialContent
    }

    requestHeaders.authorizeFor(method: .GET, url: url, config: storage.config)
    let request = try HTTPClient.Request(url: url, method: .GET, headers: requestHeaders)

    // Generate the provisional response, which will be modified later once AZS
    // comes back to us with at least the headers response (this is done in the streaming delegate)
    var responseHeaders = HTTPHeaders([])
    if let fileName = fileName {
      responseHeaders.replaceOrAdd(name: "Content-Disposition", value: "inline; filename=\"\(fileName)\"")
    }
    if let headers = headers {
      responseHeaders.add(contentsOf: headers)
    }
    let provisionalResponse = Response(status: status, headers: responseHeaders)

    let promise = req.eventLoop.makePromise(of: Response.self)
    let httpClient = req.application.http.client.shared
    let delegate = StreamingResponseDelegate(response: provisionalResponse, responsePromise: promise)
    _ = httpClient.execute(request: request, delegate: delegate, eventLoop: .delegate(on: req.eventLoop))
    return promise.futureResult
  }

  public func test() -> Response {
    let response = Response(status: .ok, headers: HTTPHeaders([]))
    response.body = Vapor.Response.Body.init(stream: { writer in
    })
    return response
  }
}
