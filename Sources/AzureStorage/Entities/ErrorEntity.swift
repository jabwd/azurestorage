//
//  ErrorEntity.swift
//  
//
//  Created by Antwan van Houdt on 06/03/2021.
//

import Foundation

public struct ErrorEntity: Codable {
  public let code: String
  public let message: String
  public let authenticationErrorDetail: String?

  public enum CodingKeys: String, CodingKey {
    case code = "Code"
    case message = "Message"
    case authenticationErrorDetail = "AuthenticationErrorDetail"
  }
}
