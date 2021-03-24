//
//  EnumerationResultsEntity.swift
//  
//
//  Created by Antwan van Houdt on 14/01/2021.
//

// TODO: Should figure out if i could make this more generic
// or perhaps not use codable and all and bite the bullet to go for libxml or something.

import Foundation

struct ContainersEnumerationResultsEntity: Codable {
  let prefix: String?
  let maxResults: Int?
  let serviceEndpoint: String
  let containers: ContainersEntity
  let nextMarker: String?

  public enum CodingKeys: String, CodingKey {
    case prefix = "Prefix"
    case maxResults = "MaxResults"
    case serviceEndpoint = "ServiceEndpoint"
    case containers = "Containers"
    case nextMarker = "NextMarker"
  }

  struct ContainersEntity: Codable {
    let list: [ContainerEntity]

    public enum CodingKeys: String, CodingKey {
      case list = "Container"
    }
  }
}

struct BlobsEnumerationResultsEntity: Codable {
  let prefix: String?
  let maxResults: Int?
  let serviceEndpoint: String
  let blobs: ContainersEntity
  let nextMarker: String?

  public enum CodingKeys: String, CodingKey {
    case prefix = "Prefix"
    case maxResults = "MaxResults"
    case serviceEndpoint = "ServiceEndpoint"
    case blobs = "Blobs"
    case nextMarker = "NextMarker"
  }

  struct ContainersEntity: Codable {
    let list: [BlobEntity]

    public enum CodingKeys: String, CodingKey {
      case list = "Blob"
    }
  }
}
