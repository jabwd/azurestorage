//
//  ContainerError.swift
//  
//
//  Created by Antwan van Houdt on 21/01/2021.
//

import Vapor

public enum ContainerError: AbortError {
    case listFailed

    public var reason: String {
        switch self {
        case .listFailed:
            return "Listing containers failed"
        }
    }

    public var status: HTTPStatus {
        switch self {
        case .listFailed:
            return .badRequest
        }
    }
}
