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

public final class AsyncDownloadDelegate: HTTPClientResponseDelegate {
  public typealias Response = Void

  public let filePath: String
  public let fileio: NonBlockingFileIO
  private var fileHandle: NIOFileHandle?

  public init(writingToPath filePath: String, fileio: NonBlockingFileIO) {
    self.filePath = filePath
    self.fileio = fileio
  }

  public func didReceiveHead(
    task: HTTPClient.Task<Response>,
    _ head: HTTPResponseHead
  ) -> EventLoopFuture<Void> {
    // The only thing we need to do here is check whether the status code is valid
    // the rest of the header I don't care about right now
    if head.status == .ok {
      return self.fileio.openFile(path: filePath, mode: .write, eventLoop: task.eventLoop).map { fileHandle in
        self.fileHandle = fileHandle
      }
    }
    return task.eventLoop.makeFailedFuture(Abort(head.status, reason: "Download failed with status"))
  }

  public func didReceiveBodyPart(
    task: HTTPClient.Task<Response>,
    _ buffer: ByteBuffer
  ) -> EventLoopFuture<Void> {
    guard let fileHandle = self.fileHandle else {
      return task.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "No filehandle for downloading to \(filePath)"))
    }
    return fileio.write(fileHandle: fileHandle, buffer: buffer, eventLoop: task.eventLoop)
  }

  public func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Response {
    // this is called when the request is fully read, called once
    // this is where you return a result or throw any errors you require to propagate to the client
    //
    do {
      try self.fileHandle?.close()
      self.fileHandle = nil
    } catch {
      print("\(error)")
    }
  }

  public func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {
    do {
      try self.fileHandle?.close()
      self.fileHandle = nil
    } catch {
      print("\(error)")
    }
    print("\(error)")
  }
}
