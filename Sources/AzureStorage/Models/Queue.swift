//
//  Queue.swift
//
//
//  Created by Antwan van Houdt on 03/02/2021.
//

import Foundation
import XMLParsing
import NIO
import NIOHTTP1

public struct Queue {
  public let name: String
  public let storage: AzureStorage

  public init(name: ContainerName, account: AzureStorage) {
    self.name = name.value
    self.storage = account
  }

  public func publish<T: Encodable>(message: Queue.Message<T>, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
    guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
      return eventLoop.makeFailedFuture(QueueError.invalidQueueName)
    }
    let endpoint = storage.config.queueEndpoint.absoluteString
    guard let url = URL(string: "\(endpoint)/\(name)/messages?visibilitytimeout=\(message.secondsHidden)&messagettl=\(message.expiresInSeconds)") else {
      return eventLoop.makeFailedFuture(QueueError.operationFailed)
    }
    do {
      let payloadStr = (try JSONEncoder().encode(message.payload)).base64EncodedString()
      let container = MessageContainer(messageText: payloadStr)
      let body = [UInt8](try XMLEncoder().encode(container, withRootKey: "QueueMessage"))
      return try storage.execute(.POST, url: url, body: body).flatMap { response -> EventLoopFuture<Void> in
        if response.status == .created {
          return eventLoop.makeSucceededFuture(())
        }
        return eventLoop.makeFailedFuture(QueueError.invalidQueueName)
      }
    } catch {
      return eventLoop.makeFailedFuture(error)
    }
  }

  public func peek<T: Decodable>(count: Int = 32, on eventLoop: EventLoop) -> EventLoopFuture<[Message<T>]> {
    guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
      return eventLoop.makeFailedFuture(QueueError.invalidQueueName)
    }
    let endpoint = storage.config.queueEndpoint.absoluteString
    guard let url = URL(string: "\(endpoint)/\(name)/messages?peekonly=true&numofmessages=\(count)") else {
      return eventLoop.makeFailedFuture(QueueError.unknown("Invalid endpoint"))
    }
    return try! storage.execute(.GET, url: url).flatMapThrowing { response -> [Message<T>] in
      guard response.status == .ok else {
        throw QueueError.unknown(response.body.debugDescription)
      }
      guard var body = response.body else {
        throw QueueError.unknown("Error from storage: \(response.status)")
      }
      let readableBytes = body.readableBytes
      let data = body.readData(length: readableBytes) ?? Data()
      let decoder = XMLDecoder()
      let result = try decoder.decode(MessageList.self, from: data)
      let list = result.messages?.compactMap {
        Message<T>($0)
      } ?? []
      return list
    }.hop(to: eventLoop)
  }

  public func fetch<T: Decodable>(count: Int = 32, visibilityTimeout: Int = 30, on eventLoop: EventLoop) -> EventLoopFuture<[Message<T>]> {
    guard visibilityTimeout > 0 else {
      return eventLoop.makeFailedFuture(QueueError.invalidVisibilityTimeout)
    }
    guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
      return eventLoop.makeFailedFuture(QueueError.invalidQueueName)
    }
    let endpoint = storage.config.queueEndpoint.absoluteString
    guard let url = URL(string: "\(endpoint)/\(name)/messages?numofmessages=\(count)&visibilitytimeout=\(visibilityTimeout)") else {
      return eventLoop.makeFailedFuture(QueueError.invalidQueueName)
    }
    return try! storage.execute(.GET, url: url).flatMapThrowing { response -> [Message<T>] in
      guard response.status == .ok else {
        throw QueueError.unknown(response.body.debugDescription)
      }
      guard var body = response.body else {
        throw QueueError.unknown("Error from storage: \(response.status)")
      }
      let readableBytes = body.readableBytes
      let data = body.readData(length: readableBytes) ?? Data()
      let decoder = XMLDecoder()
      let result = try decoder.decode(MessageList.self, from: data)
      let list = result.messages?.compactMap {
        Message<T>($0)
      } ?? []
      return list
    }.hop(to: eventLoop)
  }

  /// Attempts to create the queue with `name` in the given storage account
  /// - Parameter storageAccount: the AzureStorage instance to use for communication with azure or the emulator
  /// - Returns: Succeeded future on success
  public func create(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
    guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
      return eventLoop.makeFailedFuture(QueueError.invalidQueueName)
    }
    let queueEndpoint = storage.config.queueEndpoint.absoluteString
    guard let url = URL(string: "\(queueEndpoint)/\(name)") else {
      return eventLoop.makeFailedFuture(QueueError.invalidQueueName)
    }
    return try! storage.execute(.PUT, url: url).flatMapThrowing { response -> Void in
      guard response.status == .created || response.status == .noContent else {
        throw QueueError.unknown("Unable to create queue")
      }
    }
  }

  /// Deletes the given Queue from your storage account
  /// - Parameter storageAccount: AzureStorage instance from your vapor application
  /// - Returns: Succeeded future on success or a failed future with currently no descriptive error message
  public func delete(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
    guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
      return eventLoop.makeFailedFuture(QueueError.invalidQueueName)
    }
    let queueEndpoint = storage.config.queueEndpoint.absoluteString
    guard let url = URL(string: "\(queueEndpoint)/\(name)") else {
      return eventLoop.makeFailedFuture(QueueError.invalidQueueName)
    }
    return try! storage.execute(.DELETE, url: url).flatMapThrowing { response -> Void in
      guard response.status == .noContent else {
        throw QueueError.operationFailed
      }
    }
  }

  public func delete<T: Decodable>(message: Message<T>, on eventLoop: EventLoop) -> EventLoopFuture<Void> {
    guard let popReceipt = message.popReceipt else {
      return eventLoop.makeFailedFuture(QueueError.unknown("No pop receipt available"))
    }
    guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
      return eventLoop.makeFailedFuture(QueueError.invalidQueueName)
    }
    let queueEndpoint = storage.config.queueEndpoint.absoluteString
    let messageID = try! message.requireID().uuidString
    guard let url = URL(string: "\(queueEndpoint)/\(name.lowercased())/messages/\(messageID.lowercased())?popreceipt=\(popReceipt)") else {
      return eventLoop.makeFailedFuture(QueueError.invalidQueueName)
    }
    return try! storage.execute(.DELETE, url: url).flatMapThrowing { response -> Void in
      guard response.status == .noContent else {
        throw QueueError.operationFailed
      }
    }
  }

  public func clear(on eventLoop: EventLoop) -> EventLoopFuture<Void> {
    guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
      return eventLoop.makeFailedFuture(QueueError.invalidQueueName)
    }
    let queueEndpoint = storage.config.queueEndpoint.absoluteString
    guard let url = URL(string: "\(queueEndpoint)/\(name.lowercased())/messages") else {
      return eventLoop.makeFailedFuture(QueueError.invalidQueueName)
    }
    return try! storage.execute(.DELETE, url: url).flatMapThrowing { response -> Void in
      guard response.status == .noContent else {
        throw QueueError.operationFailed
      }
    }
  }

  internal struct MessageList: Decodable {
    let messages: [QueueMessageEntity]?

    public enum CodingKeys: String, CodingKey {
      case messages = "QueueMessage"
    }

    struct QueueMessageEntity: Decodable {
      let messageID: UUID
      let insertionTime: String
      let expirationTime: String
      let dequeueCount: Int
      let messageText: String
      let popReceipt: String

      public enum CodingKeys: String, CodingKey {
        case messageID = "MessageId"
        case insertionTime = "InsertionTime"
        case expirationTime = "ExpirationTime"
        case dequeueCount = "DequeueCount"
        case messageText = "MessageText"
        case popReceipt = "PopReceipt"
      }
    }
  }

  internal struct MessageContainer: Codable {
    let messageText: String

    public enum CodingKeys: String, CodingKey {
      case messageText = "MessageText"
    }
  }

  public struct Message<T> where T: Codable {
    public let id: UUID?
    public let payload: T
    public let secondsHidden: Int
    public let expiresInSeconds: Int
    public let dequeueCount: Int?
    public let insertionTime: Date?
    public let expirationTime: Date?
    public let popReceipt: String?
    // Pop receipt anyone?

    internal init?(_ entity: MessageList.QueueMessageEntity) {
      let decoder = JSONDecoder()
      do {
        guard let body = Data(base64Encoded: entity.messageText) else {
          return nil
        }
        self.payload = try decoder.decode(T.self, from: body)
      } catch {
        return nil
      }

      // TODO: Properly decode these fields
      self.id = entity.messageID
      self.secondsHidden = 0 // TBD.
      self.expiresInSeconds = 0 // TBD.
      self.dequeueCount = entity.dequeueCount
      // <TimeNextVisible>Thu, 07 Oct 2021 09:44:51 GMT</TimeNextVisible>
      self.insertionTime = nil // TBD, need a date decoder for all these values
      self.expirationTime = nil // TBD.
      self.popReceipt = entity.popReceipt
    }

    public init(
      _ payload: T,
      secondsHidden: Int = 0,
      expiresInSeconds: Int = -1,
      dequeueCount: Int? = nil,
      insertionTime: Date? = nil,
      expirationTime: Date? = nil,
      popReceipt: String? = nil
    ) {
      self.id = nil
      self.payload = payload
      self.secondsHidden = secondsHidden
      self.expiresInSeconds = expiresInSeconds
      self.dequeueCount = dequeueCount
      self.insertionTime = insertionTime
      self.expirationTime = expirationTime
      self.popReceipt = popReceipt
    }

    func requireID() throws -> UUID {
      guard let id = self.id else {
        throw QueueError.unknown("No ID found")
      }
      return id
    }
  }
}
