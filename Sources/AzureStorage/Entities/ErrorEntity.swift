//
//  ErrorEntity.swift
//  
//
//  Created by Antwan van Houdt on 06/03/2021.
//

import Foundation

public struct ErrorEntity: Codable {
  let error: AzsError
  
  public var message: String {
    error.message
  }
  
  var code: String {
    error.code
  }
  
  var authenticationErrorDetail: String? {
    error.authenticationErrorDetail
  }
  
  struct AzsError: Codable {
    public let code: String
    public let message: String
    public let authenticationErrorDetail: String?
    
    public enum CodingKeys: String, CodingKey {
      case code = "Code"
      case message = "Message"
      case authenticationErrorDetail = "AuthenticationErrorDetail"
    }
  }
  
  public enum CodingKeys: String, CodingKey {
    case error = "Error"
  }
}
