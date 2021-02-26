//
//  RemoteIO.swift
//  
//
//  Created by Antwan van Houdt on 28/01/2021.
//

import Vapor
import NIO
import NIOHTTP1
import AsyncHTTPClient

extension Request {
    public var remoteio: RemoteIO {
        .init(
            allocator: application.allocator,
            request: self
        )
    }
}

fileprivate final class DownloadSession: HTTPClientResponseDelegate {
    public typealias Response = Vapor.Response

    var count = 0
    var response: Vapor.Response = Vapor.Response()

    // Create future, return Response object in get head
    // Write data to the given response body stream in the delegate calls
    // Call completed in the didFinishRequest i guess?

    func didSendRequest(task: HTTPClient.Task<Response>) {
        // this is executed when request is fully sent, called once
    }

    func didReceiveHead(
        task: HTTPClient.Task<Response>,
        _ head: HTTPResponseHead
    ) -> EventLoopFuture<Void> {
        // this is executed when we receive HTTP response head part of the request
        // (it contains response code and headers), called once in case backpressure
        // is needed, all reads will be paused until returned future is resolved
        response.status = head.status
        response.headers = head.headers
        return task.eventLoop.makeSucceededFuture(())
    }

    func didReceiveBodyPart(
        task: HTTPClient.Task<Response>,
        _ buffer: ByteBuffer
    ) -> EventLoopFuture<Void> {
        // this is executed when we receive parts of the response body, could be called zero or more times
        count += buffer.readableBytes
        // in case backpressure is needed, all reads will be paused until returned future is resolved
        return task.eventLoop.makeSucceededFuture(())
    }

    func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Int {
        // this is called when the request is fully read, called once
        // this is where you return a result or throw any errors you require to propagate to the client
        return count
    }

    func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {
        // this is called when we receive any network-related error, called once
    }
}

public struct RemoteIO {
    private let allocator: ByteBufferAllocator
    private let request: Request
    private let downloadSession: DownloadSession

    var buffer: ByteBuffer

    init(allocator: ByteBufferAllocator, request: Request) {
        self.allocator = allocator
        self.request = request
        buffer = allocator.buffer(capacity: 0)
        downloadSession = DownloadSession()
    }

    public func streamRemoteURL(_ client: ClientRequest) {
        // TODO: ETag support here
        // TODO: Range support here with partialContent
        let request = try! HTTPClient.Request(
            url: URL(string: client.url.string)!,
            method: client.method,
            headers: client.headers,
            body: client.body.map { .byteBuffer($0) }
        )
        self.request.application.http.client.shared.execute(
            request: request,
            delegate: downloadSession
        )

        let response = Response(status: .ok, headers: client.headers)
        response.body = .init(stream: { stream in
            self.read().whenComplete { result in
                switch result {
                case .failure(let error):
                    stream.write(.error(error), promise: nil)
                case .success:
                    stream.write(.end, promise: nil)
                }
            }
        })
    }

    public func read() -> EventLoopFuture<Void> {
        return request.eventLoop.makeFailedFuture(BlobError.unknown(""))
    }
}

//public final class DownloadDelegate: HTTPClientResponseDelegate {
//    public typealias Response = ByteBuffer
//
//    let buffer: ByteBuffer
//
//    init() {
//        buffer = ByteBuffer()
//    }
//
//    // MARK: -
//
//    public func didReceiveBodyPart(
//        task: HTTPClient.Task<Response>,
//        _ buffer: ByteBuffer
//    ) -> EventLoopFuture<Void> {
//        // return writeStream.write(.buffer(buffer))
//        return task.eventLoop.makeSucceededFuture(())
//    }
//
//    public func didFinishRequest(task: HTTPClient.Task<Response>) throws -> ByteBuffer {
//        return buffer
//    }
//
//    public func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {
//        // this is called when we receive any network-related error, called once
//        print("Network error: \(error)")
//    }
//}

