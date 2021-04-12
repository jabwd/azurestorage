//
//  BlobError.swift
//  
//
//  Created by Antwan van Houdt on 21/01/2021.
//

import Vapor

public enum BlobError: Error {
  case unknown(String)
  case notImplemented

  case blobNotFound
  case containerNotFound
  case authorizationFailed
}

extension BlobError: AbortError {
  public var reason: String {
    switch self {
    case .unknown(let reason):
      return reason
    case .notImplemented:
      return "Endpoint not implemented"
    case .blobNotFound:
      return "Blob not found"
    case .containerNotFound:
      return "Container not found"
    case .authorizationFailed:
      return "Authorization to azurestorage failed"
    }
  }

  public var status: HTTPResponseStatus {
    switch self {
    case .unknown(_):
      return .internalServerError
    case .notImplemented:
      return .notImplemented
    case .blobNotFound, .containerNotFound:
      return .notFound
    case .authorizationFailed:
      return .internalServerError
    }
  }
}
