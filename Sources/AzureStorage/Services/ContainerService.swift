//
//  ContainerService.swift
//  
//
//  Created by Antwan van Houdt on 21/01/2021.
//

import Vapor
import XMLParsing

public final class ContainerService {
    private let storage: AzureStorage

    internal init(_ storage: AzureStorage) {
        self.storage = storage
    }

    func list() -> EventLoopFuture<[Container]> {
        let app = storage.application
        let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)/?comp=list")
        return storage.execute(.GET, url: url).flatMap { response -> EventLoopFuture<[Container]> in
            guard var body = response.body, response.status == .ok else {
                app.logger.critical("List containers failed \(response)")
                return app.client.eventLoop.makeFailedFuture(ContainerError.listFailed)
            }
            let data = body.readData(length: body.readableBytes) ?? Data()
            let decoder = XMLDecoder()
            do {
                let response = try decoder.decode(ContainersEnumerationResultsEntity.self, from: data)
                let containers = response.containers.list.map { Container($0) }
                return app.client.eventLoop.makeSucceededFuture(containers)
            } catch {
                return app.client.eventLoop.makeFailedFuture(error)
            }
        }
    }

    func create() throws -> EventLoopFuture<Void> {
        throw Abort(.notImplemented)
    }

    func delete() throws -> EventLoopFuture<Void> {
        throw Abort(.notImplemented)
    }
}
