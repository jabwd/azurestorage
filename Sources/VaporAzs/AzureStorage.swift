//
//  File.swift
//  
//
//  Created by Antwan van Houdt on 01/10/2021.
//

import Foundation
import AzureStorage
import Vapor

public extension Application {
  var azureStorage: AzureStorage {
    AzureStorageClient(application: self).shared
  }

  struct AzureStorageClient {
    let application: Application

    public var shared: AzureStorage {
      let lock = self.application.locks.lock(for: Key.self)
      lock.lock()
      defer { lock.unlock() }
      if let existing = self.application.storage[Key.self] {
        return existing
      }
      let new = AzureStorage(config: self.configuration, eventLoopGroupProvider: .shared(application.eventLoopGroup))
      self.application.storage.set(Key.self, to: new) {
        try $0.shutDown()
      }
      return new
    }

    public var configuration: AzureStorage.Configuration {
      get {
        self.application.storage[ConfigurationKey.self] ?? .init()
      }
      nonmutating set {
        if self.application.storage.contains(Key.self) {
          self.application.logger.warning("Cannot modify client configuration after client has been used.")
        } else {
          self.application.storage[ConfigurationKey.self] = newValue
        }
      }
    }

    struct Key: StorageKey, LockKey {
      typealias Value = AzureStorage
    }

    struct ConfigurationKey: StorageKey {
      typealias Value = AzureStorage.Configuration
    }
  }
}
