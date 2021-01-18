//
//  StorageError.swift
//  
//
//  Created by Antwan van Houdt on 05/01/2021.
//

public enum StorageError: Error {
    /// Thrown when the StoregConfiguration cannot be read for whatever reason
    /// from the supplied connection string. The specific error is given in the string value
    case invalidConnectionString(String)

    case randomBytesExhausted
    case uploadBlockFailed
}
