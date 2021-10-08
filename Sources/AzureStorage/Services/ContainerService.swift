//
//  ContainerService.swift
//  
//
//  Created by Antwan van Houdt on 21/01/2021.
//

import XMLParsing
import Foundation
import NIO
import NIOHTTP1

public struct ContainerService {
  private let storage: AzureStorage

  init(_ storage: AzureStorage) {
    self.storage = storage
  }

  // MARK: -

  /// Lists blob containers in the current blobstorage subscription
  /// - Parameter eventLoop: EventLoop to return the result on
  /// - Returns: A future result containing a list of containers
  public func listContainers(on eventLoop: EventLoop) -> EventLoopFuture<[Container]> {
    let url = URL(string: "\(storage.config.blobEndpoint.absoluteString)?comp=list")!
    do {
      return try storage.execute(.GET, url: url).flatMapThrowing { response -> [Container] in
        guard var body = response.body, response.status == .ok else {
          throw ContainerError.listFailed
        }
        guard let bytes = body.readBytes(length: body.readableBytes) else {
          throw ContainerError.unknownError("", message: "Unable to read body")
        }
        let decoder = XMLDecoder()
        let response = try decoder.decode(ContainersEnumerationResultsEntity.self, from: Data(bytes))
        return response.containers.list.map { Container($0) }
      }.hop(to: eventLoop)
    } catch {
      return eventLoop.makeFailedFuture(error)
    }
  }

  /// Lists the blobs available in a given container
  /// - Parameters:
  ///   - container: Container name to list
  ///   - eventLoop: EventLoop to return the resulting blob list on
  /// - Returns: A future result of a list of blobs
  public func listBlobs(_ container: String, on eventLoop: EventLoop) -> EventLoopFuture<[Blob]> {
    let url = URL(string: "\(storage.config.blobEndpoint.absoluteString)/\(container)?restype=container&comp=list")!
    do {
      return try storage.execute(.GET, url: url).flatMapThrowing { response -> [Blob] in
        guard var body = response.body else {
          return []
        }
        guard let bytes = body.readBytes(length: body.readableBytes) else {
          return []
        }
        let decoder = XMLDecoder()
        let response = try decoder.decode(BlobsEnumerationResultsEntity.self, from: Data(bytes))
        let blobs = response.blobs.list.map { Blob($0) }
        return blobs
      }.hop(to: eventLoop)
    } catch {
      return eventLoop.makeFailedFuture(error)
    }
  }

  public func createIfNotExists(_ container: String, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
    self.listContainers(on: eventLoop).flatMap { containers -> EventLoopFuture<Void> in
      if (containers.first { $0.name.value == container } != nil) {
        return eventLoop.makeSucceededFuture(())
      }
      return self.create(container, on: eventLoop)
    }
  }

  public func create(_ container: String, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
    let url = URL(string: "\(storage.config.blobEndpoint.absoluteString)/\(container)?restype=container")!
    do {
      return try storage.execute(.PUT, url: url).flatMapThrowing { response in
        if response.status == .created {
          return
        }

        guard let error = response.azsError else {
          throw ContainerError.unknownError(container, message: "\(response.status)")
        }
        throw ContainerError.createFailed(container, error: error)
      }.hop(to: eventLoop)
    } catch {
      return eventLoop.makeFailedFuture(error)
    }
  }

  public func delete(_ container: String, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
    let url = URL(string: "\(storage.config.blobEndpoint.absoluteString)/\(container)?restype=container")!
    do {
      return try storage.execute(.DELETE, url: url).flatMapThrowing { response in
        if response.status == .accepted {
          return
        }
        // attempt to decode the error message that azure storage is returning
        // for easier debugging
        guard let error = response.azsError else {
          throw ContainerError.deleteFailed(container, error: nil)
        }
        throw ContainerError.deleteFailed(container, error: error)
      }.hop(to: eventLoop)
    } catch {
      return eventLoop.makeFailedFuture(error)
    }
  }
}
