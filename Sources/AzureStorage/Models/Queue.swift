//
//  Queue.swift
//  
//
//  Created by Antwan van Houdt on 03/02/2021.
//

import XMLParsing

public struct Queue {
//    public let name: String
//
//    public init(name: String) {
//        self.name = name
//    }
//
//    public func publish<T: Encodable>(message: Queue.Message<T>, on storageAccount: AzureStorage) -> EventLoopFuture<Void> {
//        guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
//            return storageAccount.eventLoop.makeFailedFuture(QueueError.invalidQueueName)
//        }
//        let endpoint = storageAccount.configuration.queueEndpoint.absoluteString
//        let url = URI(string: "\(endpoint)/\(name)/messages?visibilitytimeout=\(message.secondsHidden)&messagettl=\(message.expiresInSeconds)")
//        do {
//            let payloadStr = (try JSONEncoder().encode(message.payload)).base64EncodedString()
//            let container = MessageContainer(messageText: payloadStr)
//            let body = [UInt8](try XMLEncoder().encode(container, withRootKey: "QueueMessage"))
//            return storageAccount.execute(.POST, url: url, body: body).flatMap { response -> EventLoopFuture<Void> in
//                if response.status == .created {
//                    return storageAccount.eventLoop.makeSucceededFuture(())
//                }
//                return storageAccount.eventLoop.makeFailedFuture(QueueError.invalidQueueName)
//            }
//        } catch {
//            return storageAccount.eventLoop.makeFailedFuture(error)
//        }
//    }
//
//    public func peek<T: Decodable>(count: Int = 32, on storageAccount: AzureStorage) -> EventLoopFuture<[Message<T>]> {
//        guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
//            return storageAccount.eventLoop.makeFailedFuture(QueueError.invalidQueueName)
//        }
//        let endpoint = storageAccount.configuration.queueEndpoint.absoluteString
//        let url = URI(string: "\(endpoint)/\(name)/messages?peekonly=true&numofmessages=\(count)")
//        return storageAccount.execute(.GET, url: url).flatMap { response -> EventLoopFuture<[Message<T>]> in
//            guard response.status == .ok else {
//                return storageAccount.eventLoop.makeFailedFuture(QueueError.unknown(response.body.debugDescription))
//            }
//            guard var body = response.body else {
//                return storageAccount.eventLoop.makeFailedFuture(QueueError.unknown("Error from storage: \(response.status)"))
//            }
//            let readableBytes = body.readableBytes
//            let data = body.readData(length: readableBytes) ?? Data()
//            let decoder = XMLDecoder()
//            do {
//                let result = try decoder.decode(MessageList.self, from: data)
//                let list = result.messages.compactMap {
//                    Message<T>($0)
//                }
//                return storageAccount.eventLoop.makeSucceededFuture(list)
//            } catch {
//                return storageAccount.eventLoop.makeFailedFuture(error)
//            }
//        }
//    }
//
//    public func fetch<T: Decodable>(count: Int = 32, on storageAccount: AzureStorage, peek: Bool = false) -> EventLoopFuture<[Message<T>]> {
//        guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
//            return storageAccount.eventLoop.makeFailedFuture(QueueError.invalidQueueName)
//        }
//        let endpoint = storageAccount.configuration.queueEndpoint.absoluteString
//        let url = URI(string: "\(endpoint)/\(name)/messages?numofmessages=\(count)")
//        return storageAccount.execute(.GET, url: url).flatMap { response -> EventLoopFuture<[Message<T>]> in
//            guard response.status == .ok else {
//                return storageAccount.eventLoop.makeFailedFuture(QueueError.unknown(response.body.debugDescription))
//            }
//            guard var body = response.body else {
//                return storageAccount.eventLoop.makeFailedFuture(QueueError.unknown("Error from storage: \(response.status)"))
//            }
//            let readableBytes = body.readableBytes
//            let data = body.readData(length: readableBytes) ?? Data()
//            let str = String(data: data, encoding: .utf8)!
//            print("XML Data: \(str)")
//            let decoder = XMLDecoder()
//            do {
//                let result = try decoder.decode(MessageList.self, from: data)
//                let list = result.messages.compactMap {
//                    Message<T>($0)
//                }
//                return storageAccount.eventLoop.makeSucceededFuture(list)
//            } catch {
//                return storageAccount.eventLoop.makeFailedFuture(error)
//            }
//        }
//    }
//
//    /// Attempts to create the queue with `name` in the given storage account
//    /// - Parameter storageAccount: the AzureStorage instance to use for communication with azure or the emulator
//    /// - Returns: Succeeded future on success
//    public func create(on storageAccount: AzureStorage) -> EventLoopFuture<Void> {
//        guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
//            return storageAccount.eventLoop.makeFailedFuture(QueueError.invalidQueueName)
//        }
//        let queueEndpoint = storageAccount.configuration.queueEndpoint.absoluteString
//        let url = URI(string: "\(queueEndpoint)/\(name)")
//        return storageAccount.execute(.PUT, url: url).flatMap { response -> EventLoopFuture<Void> in
//            if response.status == .created || response.status == .noContent {
//                return storageAccount.eventLoop.makeSucceededFuture(())
//            }
//            return storageAccount.eventLoop.makeFailedFuture(QueueError.invalidQueueName)
//        }
//    }
//
//    /// Deletes the given Queue from your storage account
//    /// - Parameter storageAccount: AzureStorage instance from your vapor application
//    /// - Returns: Succeeded future on success or a failed future with currently no descriptive error message
//    public func delete(on storageAccount: AzureStorage) -> EventLoopFuture<Void> {
//        guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
//            return storageAccount.eventLoop.makeFailedFuture(QueueError.invalidQueueName)
//        }
//        let queueEndpoint = storageAccount.configuration.queueEndpoint.absoluteString
//        let url = URI(string: "\(queueEndpoint)/\(name)")
//        return storageAccount.execute(.DELETE, url: url).flatMap { response -> EventLoopFuture<Void> in
//            guard response.status == .noContent else {
//                return storageAccount.eventLoop.makeFailedFuture(QueueError.operationFailed)
//            }
//            return storageAccount.eventLoop.makeSucceededFuture(())
//        }
//    }
//
//    internal struct MessageList: Decodable {
//        let messages: [QueueMessageEntity]
//
//        public enum CodingKeys: String, CodingKey {
//            case messages = "QueueMessage"
//        }
//
//        struct QueueMessageEntity: Decodable {
//            let messageID: UUID
//            let insertionTime: String
//            let expirationTime: String
//            let dequeueCount: Int
//            let messageText: String
//
//            public enum CodingKeys: String, CodingKey {
//                case messageID = "MessageId"
//                case insertionTime = "InsertionTime"
//                case expirationTime = "ExpirationTime"
//                case dequeueCount = "DequeueCount"
//                case messageText = "MessageText"
//            }
//        }
//    }
//
//    internal struct MessageContainer: Codable {
//        let messageText: String
//
//        public enum CodingKeys: String, CodingKey {
//            case messageText = "MessageText"
//        }
//    }
//
//    public struct Message<T> where T: Codable {
//        let payload: T
//        public let secondsHidden: Int
//        public let expiresInSeconds: Int
//        public let dequeueCount: Int?
//        public let insertionTime: Date?
//        public let expirationTime: Date?
//
//        internal init?(_ entity: MessageList.QueueMessageEntity) {
//            let decoder = JSONDecoder()
//            do {
//                guard let body = Data(base64Encoded: entity.messageText) else {
//                    return nil
//                }
//                self.payload = try decoder.decode(T.self, from: body)
//            } catch {
//                return nil
//            }
//
//            // TODO: Properly decode these fields
//            self.secondsHidden = 0 // TBD.
//            self.expiresInSeconds = 0 // TBD.
//            self.dequeueCount = entity.dequeueCount
//            self.insertionTime = nil // TBD.
//            self.expirationTime = nil // TBD.
//        }
//
//        public init(
//            _ payload: T,
//            secondsHidden: Int = 0,
//            expiresInSeconds: Int = -1,
//            dequeueCount: Int? = nil,
//            insertionTime: Date? = nil,
//            expirationTime: Date? = nil
//        ) {
//            self.payload = payload
//            self.secondsHidden = secondsHidden
//            self.expiresInSeconds = expiresInSeconds
//            self.dequeueCount = dequeueCount
//            self.insertionTime = insertionTime
//            self.expirationTime = expirationTime
//        }
//    }
}
