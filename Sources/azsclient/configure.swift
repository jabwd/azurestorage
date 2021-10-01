//
//  configure.swift
//  
//
//  Created by Antwan van Houdt on 12/04/2021.
//

import Vapor
import AzureStorage
import VaporAzs

public func configure(_ app: Application) throws {
  app.http.server.configuration.hostname = "127.0.0.1"
  app.http.server.configuration.port = 8080

  let configuration = AzureStorage.Configuration()
  app.azureStorageConfiguration = configuration

  _ = app.azureStorage.container.createIfNotExists("azurestoragetest", on: app.eventLoopGroup.next())
    .always({ result in
      switch result {
      case .success():
        print("Container azurestoragetest created")
      case .failure(let error):
        print("Unable to create container: \(error)")
      }
    })

  try routes(app)
}

public func routes(_ app: Application) throws {
  app.on(.GET, "download") { req -> EventLoopFuture<ClientResponse> in
    let response = try req.application.azureStorage.blob.read("azurestoragetest", blobName: "bigbuckbunnysmoll.mp4", on: req.eventLoop)
    return response.map { clientResponse -> ClientResponse in
      var finalResponse = clientResponse
      finalResponse.headers.replaceOrAdd(name: "Content-Disposition", value: "inline; filename=\"bigbuckbunnysmoll.mp4\"")
      let response = ClientResponse(status: finalResponse.status, headers: finalResponse.headers, body: finalResponse.body)
      return response
    }
  }

  app.on(.GET, "downloadv2") { req -> EventLoopFuture<Response> in
    return try req.application.azureStorage.blob.stream(blob: "bigbuckbunnysmoll.mp4", container: "azurestoragetest", fileName: "bigbuckbunnysmoll.mp4", headers: HTTPHeaders([
      ("content-type", "video/mp4")
    ]), with: req)
  }

  app.on(.GET, "downloadtofile") { req -> EventLoopFuture<HTTPStatus> in
    let path = "/tmp/out.mp4"
    print("Downloading")
    return try req.application.azureStorage.blob.downloadTo(filePath: path, container: "azurestoragetest", blob: "bigbuckbunny.mp4", fileio: app.fileio, on: req.eventLoop).map({ _ in
      print("Downloading done")
      return .ok
    })
  }

  app.on(.GET, "downloadtofilesmall") { req -> EventLoopFuture<HTTPStatus> in
    let path = "/tmp/out.txt"
    print("Downloading")
    return try req.application.azureStorage.blob.downloadTo(filePath: path, container: "azurestoragetest", blob: "spanish.txt", fileio: app.fileio, on: req.eventLoop).map({ _ in
      print("Downloading done")
      return .ok
    })
  }

  app.on(.GET, "testdelete") { req -> EventLoopFuture<HTTPStatus> in
    return uploadFile(req).flatMap { _ in
      return try! req.application.azureStorage.blob.delete("azurestoragetest", blobName: "bigbuckbunnysmoll.mp4", on: req.eventLoop).map { status in
        if (status) {
          return .ok
        }
        return .internalServerError
      }
    }
  }

  func uploadFile(_ req: Request) -> EventLoopFuture<HTTPStatus> {
    let path = "/Users/jabwd/Documents/videos/bigbucksmoll.mp4"
    let client = req.application.azureStorage.blob
    return req.application.fileio.openFile(path: path, eventLoop: req.eventLoop).flatMap { (fileHandle, fileRegion) -> EventLoopFuture<HTTPStatus> in
      var blockIDs: [String] = []
      let readChunkedFut = req.application.fileio.readChunked(fileRegion: fileRegion, allocator: ByteBufferAllocator(), eventLoop: req.eventLoop) { buff -> EventLoopFuture<Void> in
        return try! client.uploadBlock("azurestoragetest", blob: "bigbuckbunnysmoll.mp4", buffer: buff, on: req.eventLoop).map {
          blockIDs.append($0!)
        }
      }
      return readChunkedFut.flatMap { _ in
        try? fileHandle.close()
        return try! client.finalize("azurestoragetest", blobName: "bigbuckbunnysmoll.mp4", list: blockIDs, on: req.eventLoop).map({ response in
          return response.status
        })
      }
    }
  }

  app.on(.GET, "testupload") { req -> EventLoopFuture<HTTPStatus> in
    return uploadFile(req)
  }

  app.get("shutdown") { req -> HTTPStatus in
    guard let running = req.application.running else {
      throw Abort(.internalServerError)
    }
    running.stop()
    return .ok
  }

  let users = app.grouped("users")
  users.get { req in
    return "users"
  }
  users.get(":userID") { req in
    return req.parameters.get("userID") ?? "no id"
  }

  app.get("error") { req -> String in
    throw TestError()
  }

  app.on(.POST, "upload", body: .stream) { req -> EventLoopFuture<HTTPStatus> in

    enum BodyStreamWritingToDiskError: Error {
      case streamFailure(Error)
      case fileHandleClosedFailure(Error)
      case multipleFailures([BodyStreamWritingToDiskError])
    }
    return req.application.fileio.openFile(
      path: "/Users/tanner/Desktop/foo.txt",
      mode: .write,
      flags: .allowFileCreation(),
      eventLoop: req.eventLoop
    ).flatMap { fileHandle in
      let promise = req.eventLoop.makePromise(of: HTTPStatus.self)
      req.body.drain { part in
        switch part {
        case .buffer(let buffer):
          return req.application.fileio.write(
            fileHandle: fileHandle,
            buffer: buffer,
            eventLoop: req.eventLoop
          )
        case .error(let drainError):
          do {
            try fileHandle.close()
            promise.fail(BodyStreamWritingToDiskError.streamFailure(drainError))
          } catch {
            promise.fail(BodyStreamWritingToDiskError.multipleFailures([
              .fileHandleClosedFailure(error),
              .streamFailure(drainError)
            ]))
          }
          return req.eventLoop.makeSucceededFuture(())
        case .end:
          do {
            try fileHandle.close()
            promise.succeed(.ok)
          } catch {
            promise.fail(BodyStreamWritingToDiskError.fileHandleClosedFailure(error))
          }
          return req.eventLoop.makeSucceededFuture(())
        }
      }
      return promise.futureResult
    }
  }
}

struct TestError: AbortError, DebuggableError {
  var status: HTTPResponseStatus {
    .internalServerError
  }

  var reason: String {
    "This is a test."
  }

  var source: ErrorSource?
  var stackTrace: StackTrace?

  init(
    file: String = #file,
    function: String = #function,
    line: UInt = #line,
    column: UInt = #column,
    range: Range<UInt>? = nil,
    stackTrace: StackTrace? = .capture(skip: 1)
  ) {
    self.source = .init(
      file: file,
      function: function,
      line: line,
      column: column,
      range: range
    )
    self.stackTrace = stackTrace
  }
}

