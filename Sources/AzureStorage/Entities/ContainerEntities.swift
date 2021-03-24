//
//  ContainerList.swift
//  
//
//  Created by Antwan van Houdt on 14/01/2021.
//

import Foundation

struct ContainerEntity: Codable {
  let name: String
  let properties: Properties

  public enum CodingKeys: String, CodingKey {
    case name = "Name"
    case properties = "Properties"
  }

  struct Properties: Codable {
    let lastModified: String
    let etag: String
    let leaseStatus: String
    let leaseState: String
    let immutibilityPolicy: Bool?
    let legalHold: Bool?

    public enum CodingKeys: String, CodingKey {
      case lastModified = "Last-Modified"
      case etag = "Etag"
      case leaseStatus = "LeaseStatus"
      case leaseState = "LeaseState"
      case immutibilityPolicy = "HasImmutabilityPolicy"
      case legalHold = "HasLegalHold"
    }
  }
}
