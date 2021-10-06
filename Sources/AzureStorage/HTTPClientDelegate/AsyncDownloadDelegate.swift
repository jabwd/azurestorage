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
import Logging

public typealias AsyncDownloadCompletionHandler = () -> Void

public final class AsyncDownloadDelegate: HTTPClientResponseDelegate {
  public typealias Response = Void

  public let filePath: String
  public let fileio: NonBlockingFileIO
  private var fileHandle: NIOFileHandle?
  private var bufferBacklog: [ByteBuffer] = []
  private var didReceiveEnd: Bool = false
  private let completionHandler: AsyncDownloadCompletionHandler
  private let logger: Logger

  public init(writingToPath filePath: String, fileio: NonBlockingFileIO, completion: @escaping AsyncDownloadCompletionHandler) {
    self.logger = Logger(label: "azurestorage")
    self.filePath = filePath
    self.fileio = fileio
    self.completionHandler = completion
  }

  deinit {
    if self.fileHandle != nil {
      do {
        try self.fileHandle?.close()
      } catch {

      }
      self.fileHandle = nil
    }
  }

  public func didReceiveHead(
    task: HTTPClient.Task<Response>,
    _ head: HTTPResponseHead
  ) -> EventLoopFuture<Void> {
    self.logger.trace("Recv download HEAD")
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
    return task.eventLoop.makeFailedFuture(StorageError.downloadFailed(head.status))
  }

  private func writeBacklog(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
    guard let fileHandle = self.fileHandle else {
      // no file handle to write to the backlog
      return eventLoop.makeFailedFuture(StorageError.downloadFailed(.internalServerError))
    }
    var buffers: [EventLoopFuture<Void>] = []
    for buffer in bufferBacklog {
      let future = self.fileio.write(fileHandle: fileHandle, buffer: buffer, eventLoop: eventLoop)
      buffers.append(future)
    }
    return buffers.flatten(on: eventLoop).map { _ in
      // Make sure these are deallocated as soon as we don't need them anymore;
      // this reduces our peak memory usage (hopefully)
      buffers = []
    }
  }

  public func didReceiveBodyPart(
    task: HTTPClient.Task<Response>,
    _ buffer: ByteBuffer
  ) -> EventLoopFuture<Void> {
    logger.trace("Received download body part")
    guard let fileHandle = self.fileHandle else {
      if didReceiveEnd {
        logger.error("Received body part after request closed, this should never happen")
      }
      bufferBacklog.append(buffer)
      logger.trace("Writting to download backlog")
      return task.eventLoop.makeSucceededFuture(())
    }
    return fileio.write(fileHandle: fileHandle, buffer: buffer, eventLoop: task.eventLoop)
  }

  public func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Response {
    self.logger.trace("Download finished")
    didReceiveEnd = true
    if let fileHandle = self.fileHandle {
      try? fileHandle.close()
      self.fileHandle = nil
      self.logger.trace("Closing filehandle, download completed")
      completionHandler()
    }
  }

  public func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {
    self.logger.error("Download error: \(error)")
    didReceiveEnd = true
  }
}
