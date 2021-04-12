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

public final class StreamingResponseDelegate: HTTPClientResponseDelegate {
  public typealias Response = Void
  private let writer: BodyStreamWriter

  private var head: HTTPResponseHead?
  private var tempBody: ByteBuffer?

  init(writer: BodyStreamWriter) {
    self.writer = writer
  }

  public func didReceiveHead(
    task: HTTPClient.Task<Response>,
    _ head: HTTPResponseHead
  ) -> EventLoopFuture<Void> {
    self.head = head
    return task.eventLoop.makeSucceededFuture(())
  }

  public func didReceiveBodyPart(
    task: HTTPClient.Task<Response>,
    _ buffer: ByteBuffer
  ) -> EventLoopFuture<Void> {
    // In case we don't have a 200 status code we will try to buffer the body
    // so we can return an error if needed once the requests finishes
    if head?.status != .ok {
      if tempBody != nil {
        var buffer = buffer
        tempBody?.writeBuffer(&buffer)
      } else {
        tempBody = ByteBuffer(buffer: buffer)
      }
      return task.eventLoop.makeSucceededFuture(())
    }
    return writer.write(.buffer(buffer))
  }

  public func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Response {
    // this is called when the request is fully read, called once
    // this is where you return a result or throw any errors you require to propagate to the client
    if head?.status != .ok {
      return writer.write(.error(BlobError.unknown("storage backend error")), promise: nil)
    }
    return writer.write(.end, promise: nil)
  }

  public func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {
    // this is called when we receive any network-related error, called once
    _ = writer.write(.error(error), promise: nil)
    print("Streaming error received: \(error)")
  }
}
