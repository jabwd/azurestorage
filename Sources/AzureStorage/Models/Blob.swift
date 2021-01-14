//
//  Blob.swift
//  
//
//  Created by Antwan van Houdt on 14/01/2021.
//

import Foundation

public struct Blob: Codable, CustomStringConvertible {
    public let name: String
    public let created: Date?
    public let lastModified: Date?
    public let etag: String
    public let count: Int
    public let contentType: String
    public let encoding: String?
    public let md5Hash: String
    public let blobType: String
    public let leaseStatus: String
    public let leaseState: String
    public let accessTier: String?
    public let accessTierInferred: Bool?

    init(_ entity: BlobEntity) {
        self.name = entity.name
        self.created = DateFormatter.xMSDateFormatter.date(from: entity.properties.creationTime ?? "")
        self.lastModified = DateFormatter.xMSDateFormatter.date(from: entity.properties.lastModified ?? "")
        self.etag = entity.properties.etag
        self.count = entity.properties.contentLength
        self.contentType = entity.properties.contentType
        self.encoding = entity.properties.contentEncoding
        self.md5Hash = entity.properties.contentMD5
        self.blobType = entity.properties.blobType
        self.leaseStatus = entity.properties.leaseStatus
        self.leaseState = entity.properties.leaseState
        self.accessTier = entity.properties.accessTier
        self.accessTierInferred = entity.properties.accessTierInferred
    }

    public var description: String {
        """
Blob {
    name = "\(name)",
    created = "\(self.created?.description ?? "Unknown")",
    count = \(count)
}
"""
    }
}
