//
//  Container.swift
//  
//
//  Created by Antwan van Houdt on 14/01/2021.
//

import Foundation

public struct Container: Codable, CustomStringConvertible {
  public let name: String
  public let lastModified: Date?
  public let etag: String
  public let leaseStatus: String
  public let leaseState: String
  public let immutibilityPolicy: Bool?
  public let legalHold: Bool?
  
  init(_ entity: ContainerEntity) {
    self.name = entity.name
    self.lastModified = DateFormatter.xMSDateFormatter.date(from: entity.properties.lastModified)
    self.etag = entity.properties.etag
    self.leaseStatus = entity.properties.leaseStatus
    self.leaseState = entity.properties.leaseState
    self.immutibilityPolicy = entity.properties.immutibilityPolicy
    self.legalHold = entity.properties.legalHold
  }
  
  public var description: String {
    """
Container {
    name = "\(name)",
    lastModified = \(lastModified?.description ?? "Unknown"),
    etag = "\(etag)"
    leaseStatus = "\(leaseStatus)"
    leaseState = "\(leaseState)"
}
"""
  }
}
