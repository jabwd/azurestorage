//
//  ContainerError.swift
//  
//
//  Created by Antwan van Houdt on 21/01/2021.
//

import Vapor

public enum ContainerError: AbortError {
  case listFailed
  case deleteFailed(_ container: String, error: ErrorEntity?)
  case createFailed(_ container: String, error: ErrorEntity?)
  case unknownError(_ container: String, message: String?)

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
      return "Unknown error with container \(container): \(message)"
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
