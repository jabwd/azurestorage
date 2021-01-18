//
//  StorageRequest.swift
//  
//
//  Created by Antwan van Houdt on 18/01/2021.
//

import Vapor

internal struct StorageRequest {
    let endpoint: String
    let method: HTTPMethod
    let queryParams: [(key: String, value: String)]
    let contentType: String
    let body: [UInt8]
}
