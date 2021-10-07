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

  /// Optional. Specifies the new visibility timeout value, in seconds, relative to server time.
  /// The default value is 30 seconds.
  /// A specified value must be larger than or equal to 1 second, and cannot be larger than 7 days,
  /// or larger than 2 hours on REST protocol versions prior to version 2011-08-18.
  /// The visibility timeout of a message can be set to a value later than the expiry time.
  case invalidVisibilityTimeout

  case unknown(String)
}
