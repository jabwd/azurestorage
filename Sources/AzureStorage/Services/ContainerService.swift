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

    /// Lits all the available container names in a azure storage subscription
    /// - Parameter client: A `HTTPClient` to perform work on. This client should be on your current `EventLoop`
    /// - Returns: A future containing a list of available containers to work with
    public func list(on client: Client) -> EventLoopFuture<[Container]> {
        let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)/?comp=list")
        return storage.execute(.GET, url: url, on: client).flatMap { response -> EventLoopFuture<[Container]> in
            guard var body = response.body, response.status == .ok else {
                return client.eventLoop.makeFailedFuture(ContainerError.listFailed)
            }
            let data = body.readData(length: body.readableBytes) ?? Data()
            let decoder = XMLDecoder()
            do {
                let response = try decoder.decode(ContainersEnumerationResultsEntity.self, from: data)
                let containers = response.containers.list.map { Container($0) }
                return client.eventLoop.makeSucceededFuture(containers)
            } catch {
                return client.eventLoop.makeFailedFuture(error)
            }
        }
    }

    /// Convenience method that lists all available containers first, if the wanted container is not found
    /// it will attempt to create one.
    /// - Parameters:
    ///   - container: Container name to ensure exists
    ///   - client: A `HTTPClient` to perform work on. This client should be on your current `EventLoop`
    /// - Returns: Succeeded future if the container exists or has been created successfully
    public func createIfNotExists(_ container: String, on client: Client) -> EventLoopFuture<Void> {
        self.list(on: client).flatMap { containers -> EventLoopFuture<Void> in
            if (containers.first { $0.name == container } != nil) {
                return client.eventLoop.makeSucceededFuture(())
            }
            return self.create(container, on: client)
        }
    }


    /// Creates a container on the currently configured azure storage account
    /// - Parameters:
    ///   - container: Container name to create
    ///   - client: A `HTTPClient` to perform work on. This client should be on your current `EventLoop`
    /// - Returns: Succeeded future if the container was created
    public func create(_ container: String, on client: Client) -> EventLoopFuture<Void> {
        let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)\(container)?restype=container")
        return storage.execute(.PUT, url: url, on: client).flatMap { response -> EventLoopFuture<Void> in
            if response.status == .created {
                return client.eventLoop.makeSucceededFuture(())
            }

            guard let error = response.azsError else {
                return client.eventLoop.makeFailedFuture(ContainerError.deleteFailed(container: container, error: nil))
            }
            return client.eventLoop.makeFailedFuture(ContainerError.deleteFailed(container: container, error: error))
        }
    }

    /// Attemps to delete a given container from the configured storage account
    /// - Parameters:
    ///   - container: The name of the container to delete (Should be URL safe)
    ///   - client: A `HTTPClient` to work on. This client should be on your current `EventLoop`, in request handlers use the request's client
    /// - Returns: Succeeded futer if the container was deleted succesfully
    public func delete(_ container: String, on client: Client) -> EventLoopFuture<Void> {
        let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)/\(container)?restype=container")
        return storage.execute(.DELETE, url: url, on: client).flatMap { response -> EventLoopFuture<Void> in
            if response.status == .accepted {
                return client.eventLoop.makeSucceededFuture(())
            }
            // attempt to decode the error message that azure storage is returning
            // for easier debugging
            guard let error = response.azsError else {
                return client.eventLoop.makeFailedFuture(ContainerError.deleteFailed(container: container, error: nil))
            }
            return client.eventLoop.makeFailedFuture(ContainerError.deleteFailed(container: container, error: error))
        }
    }
}
