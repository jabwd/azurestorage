//
//  QueueError.swift
//  
//
//  Created by Antwan van Houdt on 03/02/2021.
//

public enum QueueError: Error {
    case invalidQueueName
    case operationFailed
    case zeroExpirationTime
    case unknown(String)
}
