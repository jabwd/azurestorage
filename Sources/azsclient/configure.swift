//
//  configure.swift
//  
//
//  Created by Antwan van Houdt on 12/04/2021.
//

import Vapor
import AzureStorage

public func configure(_ app: Application) throws {
  app.http.server.configuration.hostname = "127.0.0.1"
  app.http.server.configuration.port = 8080

  let configuration = try StorageConfiguration("UseDevelopmentStorage=true;")
  app.azureStorageConfiguration = configuration

  try routes(app)
}

public func routes(_ app: Application) throws {
//  app.on(.GET, "createcontainer", ":name") { req -> EventLoopFuture<String> in
//    let containerName = req.parameters.get("name") ?? "testcontainer"
//    return req.application.blobContainers.create_v2(container: containerName, on: req.eventLoop).map { _ in
//      return "Created container \(containerName)"
//    }
//  }

  app.on(.GET, "download") { req -> EventLoopFuture<ClientResponse> in
    let response = req.application.blobStorage.read("azurestoragetest", blobName: "testdownload", on: req.client)
    return response.map { clientResponse -> ClientResponse in
      var finalResponse = clientResponse
      finalResponse.headers.replaceOrAdd(name: "Content-Disposition", value: "inline; filename=\"spacemarine.mp4\"")
      return finalResponse
    }
  }

  app.on(.GET, "downloadv2") { req -> EventLoopFuture<Response> in
    return try req.application.blobStorage.stream(blob: "testdownload", container: "azurestoragetest", fileName: "spacemarine.mp4", headers: HTTPHeaders([
      ("content-type", "audio/wav"),
      ("kanker", "test header krijg de tyfus")
    ]), with: req)
  }

  app.on(.GET, "downloadtofile") { req -> EventLoopFuture<HTTPStatus> in
    let path = "/tmp/out.mp4"
    print("Downloading")
    return try req.application.blobStorage.downloadTo(filePath: path, container: "azurestoragetest", blob: "testdownload", fileio: app.fileio, client: app.http.client.shared, on: req.eventLoop).map({ _ in
      print("Downloading done")
      return .ok
    })
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

