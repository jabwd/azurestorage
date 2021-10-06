//
//  Container.swift
//  
//
//  Created by Antwan van Houdt on 14/01/2021.
//

import Foundation

public struct Container: CustomStringConvertible {
  public let name: ContainerName
  public let lastModified: Date?
  public let etag: String
  public let leaseStatus: String
  public let leaseState: String
  public let immutibilityPolicy: Bool?
  public let legalHold: Bool?

  init(name: ContainerName) {
    self.name = name
    self.etag = ""
    self.leaseStatus = ""
    self.leaseState = ""
    self.lastModified = nil
    self.legalHold = nil
    self.immutibilityPolicy = nil
  }
  
  init(_ entity: ContainerEntity) {
    self.name = ContainerName(unsafeName: entity.name)
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
