//
//  ContainerError.swift
//  
//
//  Created by Antwan van Houdt on 21/01/2021.
//

import Vapor

public enum ContainerError: AbortError {
    case listFailed
    case deleteFailed(container: String, error: ErrorEntity?)
    case createFailed(container: String, error: ErrorEntity?)

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
