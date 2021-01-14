//
//  BlobEntities.swift
//  
//
//  Created by Antwan van Houdt on 14/01/2021.
//

import Vapor
import Foundation

struct BlobEntity: Codable {
    let name: String
    let properties: Properties

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case properties = "Properties"
    }

    struct Properties: Codable {
        let creationTime: String?
        let lastModified: String?
        let etag: String
        let contentLength: Int
        let contentType: String
        let contentEncoding: String?
        let contentLanguage: String?
        let contentMD5: String
        let contentDisposition: String?
        let cacheControl: String?
        let blobType: String // TODO: Make an enum out of this
        let leaseStatus: String
        let leaseState: String
        let accessTier: String?
        let accessTierInferred: Bool?

        public enum CodingKeys: String, CodingKey {
            case creationTime = "Creation-Time"
            case lastModified = "Last-Modified"
            case etag = "Etag"
            case contentLength = "Content-Length"
            case contentType = "Content-Type"
            case contentEncoding = "Content-Encoding"
            case contentLanguage = "Content-Language"
            case contentMD5 = "Content-MD5"
            case contentDisposition = "Content-Disposition"
            case cacheControl = "Cache-Control"
            case blobType = "BlobType"
            case leaseStatus = "LeaseStatus"
            case leaseState = "LeaseState"
            case accessTier = "AccessTier"
            case accessTierInferred = "AccessTierInferred"
        }
    }
}
