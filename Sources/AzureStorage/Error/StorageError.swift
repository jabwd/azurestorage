//
//  StorageError.swift
//  
//
//  Created by Antwan van Houdt on 05/01/2021.
//

import NIOHTTP1

public enum StorageError: Error {
  /// Thrown when the StoregConfiguration cannot be read for whatever reason
  /// from the supplied connection string. The specific error is given in the string value
  case invalidConnectionString(String)

  /// When encoding the generated blobID fails. Technically this should never happen.
  /// Famous last words I suppose
  case invalidBlobID
  
  /// Thrown when generating random bytes has failed
  case randomBytesExhausted

  case downloadFailed(HTTPResponseStatus)
}
