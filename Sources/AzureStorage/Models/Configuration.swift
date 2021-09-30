//
//  StorageConfiguration.swift
//  
//
//  Created by Antwan van Houdt on 05/01/2021.
//

import Vapor

public extension Application {
  var azureStorageConfiguration: AzureStorage.Configuration? {
    get {
      self.storage[StorageConfigurationKey.self]
    }
    set {
      self.storage[StorageConfigurationKey.self] = newValue
    }
  }
}

struct StorageConfigurationKey: StorageKey {
  typealias Value = AzureStorage.Configuration
}

extension AzureStorage {
  public struct Configuration: Equatable {
    public let accountName: String
    public let sharedKey: String
    public let useHttps: Bool
    public let blobEndpoint: URL
    public let queueEndpoint: URL
    public let tableEndpoint: URL

    static var development: Configuration {
      Configuration()
    }

    public init() {
      accountName = "devstoreaccount1"
      sharedKey = "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw=="
      useHttps = false
      blobEndpoint = URL(string: "http://127.0.0.1:10000/devstoreaccount1")!
      queueEndpoint = URL(string: "http://127.0.0.1:10001/devstoreaccount1")!
      tableEndpoint = queueEndpoint
    }

    /// Constructs a new configuration object
    ///  Use `UseDevelopmentStorage=true` to make use of local storage emulator
    /// - Parameter connectionString: Azure Storage connection string
    /// - Throws: A `StorageError` if its unable to parse the provided connection string
    public init(_ connectionString: String) throws {
      let strComponents = connectionString.split(separator: ";").filter { !$0.isEmpty }

      // Decode the azure storage connection string into a key value store
      // thats more easy to reason about below
      var kvStore: [String: String] = [:]
      for component in strComponents {
        let kvIndex = component.firstIndex { $0 == "=" }
        if let index = kvIndex {
          let key = component[component.startIndex..<index]
          let value = component[component.index(after: index)..<component.endIndex]
          kvStore[String(key)] = String(value)
        }
      }

      // UseDevelopmentStorage means we want to make use of the azure storage emulator ( like azurite )
      // which has very specific settings including a pre-defined static shared key
      if (kvStore["UseDevelopmentStorage"] == "true") {
        accountName = "devstoreaccount1"
        sharedKey = "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw=="
        useHttps = false
        blobEndpoint = URL(string: "http://127.0.0.1:10000/devstoreaccount1")!
        queueEndpoint = URL(string: "http://127.0.0.1:10001/devstoreaccount1")!
        tableEndpoint = queueEndpoint
        return
      }

      guard let accountKey = kvStore["AccountKey"] else {
        throw StorageError.invalidConnectionString("Missing account key")
      }
      guard let accountName = kvStore["AccountName"] else {
        throw StorageError.invalidConnectionString("Missing account name")
      }
      guard let endPointSuffix = kvStore["EndpointSuffix"] else {
        throw StorageError.invalidConnectionString("Missing endpoint suffix")
      }
      let defaultHttps = kvStore["DefaultEndpointsProtocol"] == "https" ? true : false
      self.accountName = accountName
      sharedKey = accountKey
      useHttps = defaultHttps

      blobEndpoint = URL(string: "\(defaultHttps ? "https" : "http")://\(accountName).blob.\(endPointSuffix)")!
      queueEndpoint = URL(string: "\(defaultHttps ? "https" : "http")://\(accountName).queue.\(endPointSuffix)")!
      tableEndpoint = URL(string: "\(defaultHttps ? "https" : "http")://\(accountName).table.\(endPointSuffix)")!
    }

    init(
      accountName: String,
      sharedKey: String,
      useHttps: Bool = true,
      blobEndpoint: URL,
      queueEndpoint: URL,
      tableEndpoint: URL
    ) {
      self.accountName = accountName
      self.sharedKey = sharedKey
      self.useHttps = useHttps
      self.blobEndpoint = blobEndpoint
      self.queueEndpoint = queueEndpoint
      self.tableEndpoint = tableEndpoint
    }
  }
}
