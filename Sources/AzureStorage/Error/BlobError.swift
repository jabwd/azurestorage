//
//  BlobError.swift
//  
//
//  Created by Antwan van Houdt on 21/01/2021.
//

public enum BlobError: Error {
  case unknown(String)
  case notImplemented

  case blobNotFound
  case containerNotFound
  case authorizationFailed
}
