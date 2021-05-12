//
//  BlobService.swift
//  
//
//  Created by Antwan van Houdt on 21/01/2021.
//

import Vapor
import XMLParsing
import Foundation

public final class BlobService {
  private let storage: AzureStorage

  internal init(_ storage: AzureStorage) {
    self.storage = storage
  }

  public func list(_ name: String, on client: Client) -> EventLoopFuture<[Blob]> {
    let endpoint = "/\(name)?restype=container&comp=list"
    let blobEndpoint = storage.configuration.blobEndpoint.absoluteString
    let url = URI(string: "\(blobEndpoint)\(endpoint)")
    return storage.execute(.GET, url: url, on: client).map { response -> [Blob] in
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
      }
      return []
    }
  }

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
    let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)\(endpoint)")

    var requestHeaders = HTTPHeaders.defaultAzureStorageHeaders

    // Support range header requests, add partialContent status if we only requested a number of bytes
    var status: HTTPStatus = .ok
    if req.headers.contains(name: .range) {
      requestHeaders.replaceOrAdd(name: .range, value: req.headers.first(name: .range) ?? "")
      status = .partialContent
    }

    requestHeaders.authorizeFor(method: .GET, url: url, config: storage.configuration)
    let request = try HTTPClient.Request(url: url.string, method: .GET, headers: requestHeaders)

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

  /// Attempts to download a blob to the given file destination
  /// - Parameters:
  ///   - filePath: A local writable path to save the file to, this code creates the file but does not delete it upon error
  ///   - container: Blob container
  ///   - blob: Blob name to download
  ///   - fileio: A instance of FileIO (either from request on application etc.)
  ///   - client: A HTTPClient to use for network requests
  ///   - eventLoop: The eventLoop to use for all http traffic
  /// - Throws: -
  /// - Returns: Succeeded or failed futuer
  public func downloadTo(filePath: String, container: String, blob: String, fileio: NonBlockingFileIO, client: HTTPClient, on eventLoop: EventLoop) throws -> EventLoopFuture<Void> {
    let endpoint = "/\(container)/\(blob)"
    let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)\(endpoint)")

    var requestHeaders = HTTPHeaders.defaultAzureStorageHeaders
    requestHeaders.authorizeFor(method: .GET, url: url, config: storage.configuration)
    let request = try HTTPClient.Request(url: url.string, method: .GET, headers: requestHeaders)
    let promise = eventLoop.makePromise(of: Void.self)
    let downloadDelegate = AsyncDownloadDelegate(writingToPath: filePath, fileio: fileio) {
      promise.completeWith(.success(()))
    }
    return [
      client.execute(request: request, delegate: downloadDelegate, eventLoop: .delegate(on: eventLoop)).futureResult,
      promise.futureResult
    ].flatten(on: eventLoop)
  }

  public func read(_ containerName: String, blobName: String, on client: Client) -> EventLoopFuture<ClientResponse> {
    let endpoint = "/\(containerName)/\(blobName)"
    let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)\(endpoint)")
    return storage.execute(.GET, url: url, on: client)
  }

  public func delete(_ containerName: String, blobName: String, on client: Client) -> EventLoopFuture<Bool> {
    let endpoint = "/\(containerName)/\(blobName)"
    let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)\(endpoint)")
    return storage.execute(.DELETE, url: url, on: client).map { response -> Bool in
      response.status == .accepted
    }
  }

  /// Uploads a data block to azure storage
  /// - Parameters:
  ///   - container: Blob container to upload to
  ///   - blob: Blob name to upload block for
  ///   - buffer: `ByteBuffer` of (partial chunk of your finalized blob)
  ///   - client: HTTP Client to use for executing requests
  /// - Returns: Returns a `String` containing the blockID on success
  public func uploadBlock(_ container: String, blob: String, buffer: ByteBuffer, on client: Client) -> EventLoopFuture<String?> {
    guard let blockID = Data.random(bytes: 16)?.base64EncodedString() else {
      return client.eventLoop.future(error: StorageError.randomBytesExhausted)
    }
    guard let encodedID = blockID.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics) else {
      return client.eventLoop.future(error: Abort(.internalServerError))
    }
    let endpoint = "/\(container)/\(blob)?comp=block&blockid=\(encodedID)"
    let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)\(endpoint)")
    storage.logger.trace("Uploading block \(blockID)")
    return storage.execute(.PUT, url: url, body: buffer, on: client).map { response -> String? in
      self.storage.logger.trace("Finished uploading block \(blockID)")
      if (response.status != .created) {
        return nil
      }
      return blockID
    }
  }
  
  public func finalize(_ containerName: String, blobName: String, list: [String], on client: Client) -> EventLoopFuture<ClientResponse> {
    let entity = BlockListEntity(blockIDs: list)
    let encoder = XMLEncoder()
    guard let data = try? encoder.encode(entity, withRootKey: "BlockList") else {
      return client.eventLoop.future(error: Abort(.internalServerError))
    }
    let endpoint = "/\(containerName)/\(blobName)?comp=blocklist"
    let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)\(endpoint)")
    return storage.execute(.PUT, url: url, body: Array(data), on: client).map { response -> ClientResponse in
      response
    }
  }
}
