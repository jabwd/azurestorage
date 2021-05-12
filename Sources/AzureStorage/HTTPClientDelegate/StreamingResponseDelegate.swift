//
//  ClientResponseDelegate.swift
//  
//
//  Created by Antwan van Houdt on 12/04/2021.
//

import Foundation
import AsyncHTTPClient
import NIO
import NIOHTTP1
import Vapor

fileprivate extension HTTPHeaders {
  mutating func replaceOrAddIfExists(name: HTTPHeaders.Name, value: String?) {
    if let value = value {
      self.replaceOrAdd(name: name, value: value)
    }
  }
}

public final class StreamingResponseDelegate: HTTPClientResponseDelegate {
  public typealias Response = Void

  private var head: HTTPResponseHead?
  // Any body bytes that are received before we have a bodystreamwriter
  // are stored in a temporary `ByteBuffer`
  private var tempBody: ByteBuffer?
  private let responsePromise: EventLoopPromise<Vapor.Response>
  private var writer: BodyStreamWriter?
  private let provisionalRespones: Vapor.Response
  private var completedPromise: Bool = false

  init(response: Vapor.Response, responsePromise: EventLoopPromise<Vapor.Response>) {
    self.responsePromise = responsePromise
    self.provisionalRespones = response
  }

  public func didReceiveHead(
    task: HTTPClient.Task<Response>,
    _ head: HTTPResponseHead
  ) -> EventLoopFuture<Void> {
    self.head = head
    provisionalRespones.status = head.status
    provisionalRespones.body = Vapor.Response.Body.init(stream: { streamWriter in
      self.writer = streamWriter
      // Check if there is any unwritten data that needs to be written immediately
      if let temp = self.tempBody {
        _ = self.writer?.write(.buffer(temp))
        self.tempBody = nil
      }
    })

    // Manually copy over headers we might be interested in
    // Currently the only reason the response object comes from the initializer
    // is that we simply don't know what the client wants in extra response headers.
    // this is not a raw-proxy afterall. This might be a stupid way of doing it, I'm not sure
    // and I'm sure someone in future will hate me for this
    if provisionalRespones.headers.contains(name: .contentType) == false {
      provisionalRespones.headers.replaceOrAddIfExists(name: .contentType, value: head.headers.first(name: .contentType))
    }
    provisionalRespones.headers.replaceOrAddIfExists(name: .contentRange, value: head.headers.first(name: .contentRange))
    provisionalRespones.headers.replaceOrAddIfExists(name: .eTag, value: head.headers.first(name: .eTag))
    provisionalRespones.headers.replaceOrAddIfExists(name: .lastModified, value: head.headers.first(name: .lastModified))
    provisionalRespones.headers.replaceOrAddIfExists(name: .acceptRanges, value: head.headers.first(name: .acceptRanges))

    responsePromise.succeed(provisionalRespones)
    completedPromise = true
    return task.eventLoop.makeSucceededFuture(())
  }

  public func didReceiveBodyPart(
    task: HTTPClient.Task<Response>,
    _ buffer: ByteBuffer
  ) -> EventLoopFuture<Void> {
    // In case we don't have a body writer yet we simply fill up the temporary buffer
    if writer == nil {
      if tempBody != nil {
        var buffer = buffer
        tempBody?.writeBuffer(&buffer)
      } else {
        tempBody = ByteBuffer(buffer: buffer)
      }
      return task.eventLoop.makeSucceededFuture(())
    } else if let writer = writer {
      return writer.write(.buffer(buffer))
    } else {
      return task.eventLoop.makeFailedFuture(BlobError.unknown("No body to write to was available"))
    }
  }

  public func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Response {
    // this is called when the request is fully read, called once
    // this is where you return a result or throw any errors you require to propagate to the client
    _ = writer?.write(.end, promise: nil)
  }

  public func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {
    // this is called when we receive any network-related error, called once
    _ = writer?.write(.error(error), promise: nil)
    if completedPromise == false {
      responsePromise.fail(error)
    }
    print("Streaming error received: \(error)")
  }
}
