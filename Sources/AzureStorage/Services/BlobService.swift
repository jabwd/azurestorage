//
//  BlobService.swift
//  
//
//  Created by Antwan van Houdt on 21/01/2021.
//

import Vapor
import XMLParsing
import Foundation

public final class BlobService {
    private let storage: AzureStorage

    internal init(_ storage: AzureStorage) {
        self.storage = storage
    }

    public func list(_ name: String, on client: Client) -> EventLoopFuture<[Blob]> {
        let endpoint = "/\(name)?restype=container&comp=list"
        let blobEndpoint = storage.configuration.blobEndpoint.absoluteString
        let url = URI(string: "\(blobEndpoint)\(endpoint)")
        return storage.execute(.GET, url: url, on: client).map { response -> [Blob] in
            guard var body = response.body else {
                return []
            }
            let readableBytes = body.readableBytes
            let data = body.readData(length: readableBytes) ?? Data()
            let decoder = XMLDecoder()
            do {
                let response = try decoder.decode(BlobsEnumerationResultsEntity.self, from: data)
                let blobs = response.blobs.list.map { Blob($0) }
                return blobs
            } catch {
            }
            return []
        }
    }

    public func read(_ containerName: String, blobName: String, on client: Client) -> EventLoopFuture<ClientResponse> {
        let endpoint = "/\(containerName)/\(blobName)"
        let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)\(endpoint)")
        return storage.execute(.GET, url: url, on: client)
    }

    public func delete(_ containerName: String, blobName: String, on client: Client) -> EventLoopFuture<Bool> {
        let endpoint = "/\(containerName)/\(blobName)"
        let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)\(endpoint)")
        return storage.execute(.DELETE, url: url, on: client).map { response -> Bool in
            response.status == .accepted
        }
    }

    public func uploadBlock(_ containerName: String, blobName: String, data: [UInt8], on client: Client) -> EventLoopFuture<String?> {
        guard let blockID = Data.random(bytes: 16)?.base64EncodedString() else {
            return client.eventLoop.future(error: StorageError.randomBytesExhausted)
        }
        guard let encodedID = blockID.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics) else {
            return client.eventLoop.future(error: Abort(.internalServerError))
        }
        let endpoint = "/\(containerName)/\(blobName)?comp=block&blockid=\(encodedID)"
        let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)\(endpoint)")
        return storage.execute(.PUT, url: url, body: data, on: client).map { response -> String? in
            if (response.status != .created) {
                return nil
            }
            return blockID
        }
    }

    public func finalize(_ containerName: String, blobName: String, list: [String], on client: Client) -> EventLoopFuture<ClientResponse> {
        let entity = BlockListEntity(blockIDs: list)
        let encoder = XMLEncoder()
        guard let data = try? encoder.encode(entity, withRootKey: "BlockList") else {
            return client.eventLoop.future(error: Abort(.internalServerError))
        }
        let endpoint = "/\(containerName)/\(blobName)?comp=blocklist"
        let url = URI(string: "\(storage.configuration.blobEndpoint.absoluteString)\(endpoint)")
        return storage.execute(.PUT, url: url, body: Array(data), on: client).map { response -> ClientResponse in
            response
        }
    }
}
