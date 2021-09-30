//
//  BlobService.swift
//  
//
//  Created by Antwan van Houdt on 30/09/2021.
//

import Foundation
import XMLParsing
import AsyncHTTPClient
import NIOHTTP1
import NIO

public struct BlobService {
  public let storage: AzureStorage

  internal init(_ storage: AzureStorage) {
    self.storage = storage
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
  public func downloadTo(filePath: String, container: String, blob: String, fileio: NonBlockingFileIO, on eventLoop: EventLoop) throws -> EventLoopFuture<Void> {
    let url = storage.config.blobEndpoint.appendingPathComponent(container).appendingPathComponent(blob)

    var requestHeaders = HTTPHeaders.defaultAzureStorageHeaders
    requestHeaders.authorizeFor(method: .GET, url: url, config: storage.config)
    let request = try HTTPClient.Request(url: url, method: .GET, headers: requestHeaders)
    let promise = eventLoop.makePromise(of: Void.self)
    let downloadDelegate = AsyncDownloadDelegate(writingToPath: filePath, fileio: fileio) {
      promise.completeWith(.success(()))
    }
    return [
      storage.httpClient.execute(request: request, delegate: downloadDelegate, eventLoop: .delegate(on: eventLoop)).futureResult,
      promise.futureResult
    ].flatten(on: eventLoop)
  }

  /// Performs a simple get on a blob in azure blob storage
  /// WARNING: this method will have bad performance characteristics for large files
  public func read(_ container: String, blobName: String, on eventLoop: EventLoop) throws -> EventLoopFuture<HTTPClient.Response> {
    let url = storage.config.blobEndpoint.appendingPathComponent(container).appendingPathComponent(blobName)
    return try storage.execute(.GET, url: url).hop(to: eventLoop)
  }

  /// Deletes a blob from blob storage
  public func delete(_ container: String, blobName: String, on eventLoop: EventLoop) throws -> EventLoopFuture<Bool> {
    let url = storage.config.blobEndpoint.appendingPathComponent(container).appendingPathComponent(blobName)
    return try storage.execute(.DELETE, url: url).map { response -> Bool in
      response.status == .accepted
    }.hop(to: eventLoop)
  }

  /// Uploads a data block to azure storage on its own internal eventLoop
  /// - Parameters:
  ///   - container: Blob container to upload to
  ///   - blob: Blob name to upload block for
  ///   - buffer: `ByteBuffer` of (partial chunk of your finalized blob)
  ///   - eventLoop: EventLoop to return any responses on
  /// - Returns: Returns a `String` containing the blockID on success
  public func uploadBlock(_ container: String, blob: String, buffer: ByteBuffer, on eventLoop: EventLoop) throws -> EventLoopFuture<String?> {
    guard let blockID = Data.random(bytes: 16)?.base64EncodedString() else {
      return eventLoop.makeFailedFuture(StorageError.randomBytesExhausted)
    }
    guard let encodedID = blockID.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics) else {
      return eventLoop.makeFailedFuture(StorageError.invalidBlobID)
    }
    let url = URL(string: "\(storage.config.blobEndpoint.absoluteString)/\(container)/\(blob)?comp=block&blockid=\(encodedID)")!
    storage.logger.trace("Uploading block \(blockID) \(buffer.readableBytes)")
    return try storage.execute(.PUT, url: url, body: buffer).map { response -> String? in
      self.storage.logger.trace("Finished uploading block \(blockID)")
      if (response.status != .created) {
        return nil
      }
      return blockID
    }.hop(to: eventLoop)
  }

  public func finalize(
    _ container: String,
    blobName: String,
    list: [String],
    on eventLoop: EventLoop
  ) throws -> EventLoopFuture<HTTPClient.Response> {
    let entity = BlockListEntity(blockIDs: list)
    let encoder = XMLEncoder()
    guard let data = try? encoder.encode(entity, withRootKey: "BlockList") else {
      return eventLoop.makeFailedFuture(StorageError.invalidBlobID)
    }
    let url = URL(string: "\(storage.config.blobEndpoint.absoluteString)/\(container)/\(blobName)?comp=blocklist")!
    return try storage.execute(.PUT, url: url, body: Array(data)).hop(to: eventLoop)
  }
}
