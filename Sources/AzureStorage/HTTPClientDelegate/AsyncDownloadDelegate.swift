//
//  AsyncDownloadDelegate.swift
//  
//
//  Created by Antwan van Houdt on 07/05/2021.
//

import Foundation
import AsyncHTTPClient
import NIOHTTP1
import NIO
import Vapor

public typealias AsyncDownloadCompletionHandler = () -> Void

public final class AsyncDownloadDelegate: HTTPClientResponseDelegate {
  public typealias Response = Void

  public let filePath: String
  public let fileio: NonBlockingFileIO
  private var fileHandle: NIOFileHandle?
  private var bufferBacklog: [ByteBuffer] = []
  private var didReceiveEnd: Bool = false
  private let completionHandler: AsyncDownloadCompletionHandler
  private var bufCount: Int = 0
  private var lastWrittenBuffer: Int = 0
  private var lastBuffer: Int = 0

  public init(writingToPath filePath: String, fileio: NonBlockingFileIO, completion: @escaping AsyncDownloadCompletionHandler) {
    self.filePath = filePath
    self.fileio = fileio
    self.completionHandler = completion
  }

  deinit {
    if self.fileHandle != nil {
      do {
        try self.fileHandle.close()
      } catch {

      }
      self.fileHandle = nil
    }
  }

  public func didReceiveHead(
    task: HTTPClient.Task<Response>,
    _ head: HTTPResponseHead
  ) -> EventLoopFuture<Void> {
    // The only thing we need to do here is check whether the status code is valid
    // the rest of the header I don't care about right now
    if head.status == .ok {
      return self.fileio.openFile(path: filePath, mode: .write, flags: .allowFileCreation(), eventLoop: task.eventLoop).flatMap { fileHandle in
        self.fileHandle = fileHandle

        // If before writing the entire backlog out we already received the end of the request
        // we have to close here when this is done doing its work, otherwise it has to be done later
        let shouldClose = self.didReceiveEnd
        return self.writeBacklog(on: task.eventLoop).map { _ in
          if shouldClose {
            try? self.fileHandle?.close()
            self.fileHandle = nil
          }
        }
      }
    }
    return task.eventLoop.makeFailedFuture(Abort(head.status, reason: "Download failed with status"))
  }

  private func writeBacklog(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
    guard let fileHandle = self.fileHandle else {
      return eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "No filehandle to start writing with regarding backlog"))
    }
    var buffers: [EventLoopFuture<Void>] = []
    for buffer in bufferBacklog {
      let future = self.fileio.write(fileHandle: fileHandle, buffer: buffer, eventLoop: eventLoop)
      buffers.append(future)
    }
    return buffers.flatten(on: eventLoop).map { _ in
      // Free up any memory we might still be using :), we want our peaks to be low
      buffers = []
    }
  }

  public func didReceiveBodyPart(
    task: HTTPClient.Task<Response>,
    _ buffer: ByteBuffer
  ) -> EventLoopFuture<Void> {
    bufCount += 1
    guard let fileHandle = self.fileHandle else {
      if didReceiveEnd {
        fatalError("Received body part after request closed, this should never happen")
      }
      bufferBacklog.append(buffer)
      return task.eventLoop.makeSucceededFuture(())
    }
    let writingTag = bufCount
    return fileio.write(fileHandle: fileHandle, buffer: buffer, eventLoop: task.eventLoop).map { _ in
      if writingTag == self.lastBuffer && self.didReceiveEnd {
        try? self.fileHandle?.close()
        self.fileHandle = nil
        self.lastWrittenBuffer = writingTag
        self.completionHandler()
      }
    }
  }

  public func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Response {
    lastBuffer = bufCount
    didReceiveEnd = true
    if lastWrittenBuffer == bufCount {
      if let fileHandle = self.fileHandle {
        try? fileHandle.close()
        self.fileHandle = nil
        completionHandler()
      }
    }
  }

  public func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {
    didReceiveEnd = true
  }
}
