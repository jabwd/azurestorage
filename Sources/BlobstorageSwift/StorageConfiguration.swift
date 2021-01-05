//
//  StorageConfiguration.swift
//  
//
//  Created by Antwan van Houdt on 05/01/2021.
//

import Foundation

public struct StorageConfiguration: Equatable {
    let accountName: String
    let sharedKey: String
    let useHttps: Bool
    let blobEndpoint: URL
    let queueEndpoint: URL
    let tableEndpoint: URL

    init(_ connectionString: String) throws {
        let strComponents = connectionString.split(separator: ";").filter { !$0.isEmpty }
        var kvStore: [String: String] = [:]
        for component in strComponents {
            let kvIndex = component.firstIndex { $0 == "=" }
            if let index = kvIndex {
                let key = component[component.startIndex..<index]
                let value = component[component.index(after: index)..<component.endIndex]
                kvStore[String(key)] = String(value)
            }
        }
        if (kvStore["UseDevelopmentStorage"] == "true") {
            accountName = "devstoreaccount1"
            sharedKey = "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw=="
            useHttps = false
            blobEndpoint = URL(string: "http://127.0.0.1:10000/devstoreaccount1")!
            queueEndpoint = URL(string: "http://127.0.0.1:10001/devstoreaccount1")!
            tableEndpoint = URL(string: "http://127.0.0.1:10001/devstoreaccount1")!
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

        let urlString = "\(defaultHttps ? "https" : "http")://\(accountName).\(endPointSuffix)"
        blobEndpoint = URL(string: urlString)!
        queueEndpoint = URL(string: urlString)!
        tableEndpoint = URL(string: urlString)!
    }

    init(accountName: String, sharedKey: String, useHttps: Bool, blobEndpoint: URL, queueEndpoint: URL, tableEndpoint: URL) {
        self.accountName = accountName
        self.sharedKey = sharedKey
        self.useHttps = useHttps
        self.blobEndpoint = blobEndpoint
        self.queueEndpoint = queueEndpoint
        self.tableEndpoint = tableEndpoint
    }
}
