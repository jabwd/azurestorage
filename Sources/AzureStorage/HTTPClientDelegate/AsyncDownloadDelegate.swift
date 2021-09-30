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
  private var bufCount: Int = 0
  private var lastWrittenBuffer: Int = 0
  private var lastBuffer: Int = 0
  private let logger: Logger

  public init(writingToPath filePath: String, fileio: NonBlockingFileIO, completion: @escaping AsyncDownloadCompletionHandler) {
    self.logger = Logger(label: "azurestorage")
    self.filePath = filePath
    self.fileio = fileio
    self.completionHandler = completion
  }

  deinit {
    self.logger.trace("Download delegate deinit")
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
    self.logger.info("Recv download HEAD")
    // The only thing we need to do here is check whether the status code is valid
    // the rest of the header I don't care about right now
    if head.status == .ok {
      return self.fileio.openFile(path: filePath, mode: .write, flags: .allowFileCreation(), eventLoop: task.eventLoop).flatMap { fileHandle in
        self.fileHandle = fileHandle

        // If before writing the entire backlog out we already received the end of the request
        // we have to close here when this is done doing its work, otherwise it has to be done later
        let shouldClose = self.didReceiveEnd
        self.logger.trace("Writing download backlog, should close: \(shouldClose)")
        return self.writeBacklog(on: task.eventLoop).map { _ in
          if shouldClose {
            self.logger.trace("Closing download after writing backlog")
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
      // Free up any memory we might still be using :), we want our peaks to be low
      buffers = []
    }
  }

  public func didReceiveBodyPart(
    task: HTTPClient.Task<Response>,
    _ buffer: ByteBuffer
  ) -> EventLoopFuture<Void> {
    self.logger.trace("Received download body part")
    bufCount += 1
    guard let fileHandle = self.fileHandle else {
      if didReceiveEnd {
        logger.error("Received body part after request closed, this should never happen")
      }
      bufferBacklog.append(buffer)
      logger.trace("Writting to download backlog")
      return task.eventLoop.makeSucceededFuture(())
    }
    logger.trace("Writing chunk")
    let writingTag = bufCount
    return fileio.write(fileHandle: fileHandle, buffer: buffer, eventLoop: task.eventLoop).map { _ in
      self.lastWrittenBuffer = writingTag
      print("Written buffer \(writingTag)")
      self.logger.trace("Written buffer \(writingTag)")
      if writingTag == self.lastBuffer && self.didReceiveEnd {
        self.logger.trace("End received while writing buffers, closing filehandle")
        print("Writing now closing")
        try? self.fileHandle?.close()
        self.fileHandle = nil
        self.completionHandler()
      }
    }
  }

  public func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Response {
    self.logger.trace("Request finished?")
    lastBuffer = bufCount
    didReceiveEnd = true
    self.logger.trace("Last written buffer: \(lastWrittenBuffer), bufCount: \(bufCount)")
    print("Request finished")
    if lastWrittenBuffer == bufCount {
      if let fileHandle = self.fileHandle {
        try? fileHandle.close()
        self.fileHandle = nil
        self.logger.trace("Closing filehandle, download completed")
        completionHandler()
      }
    }
  }

  public func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {
    self.logger.error("Download error: \(error)")
    didReceiveEnd = true
  }
}
