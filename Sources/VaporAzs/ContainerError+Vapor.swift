//
//  ContainerError+Vapor.swift
//  
//
//  Created by Antwan van Houdt on 02/10/2021.
//

import AzureStorage
import Vapor

extension ContainerError: AbortError {
  public var reason: String {
    switch self {
    case .listFailed:
      return "Listing containers failed"
    case .deleteFailed(let container, let error):
      if let error = error {
        return "Error deleting container \(container): \(error.message)"
      }
      return "Error deleting container \(container): unknown reason"
    case .createFailed(let container, let error):
      if let error = error {
        return "Error deleting container \(container): \(error.message)"
      }
      return "Error deleting container \(container): unknown reason"
    case .unknownError(let container, let message):
      if let errorMessage = message {
        return "Error with container `\(container)`: \(errorMessage)"
      }
      return "Unknown error with container \(container)"
    }
  }

  public var status: HTTPStatus {
    switch self {
    case .listFailed:
      return .badRequest
    default:
      return .badRequest
    }
  }
}
