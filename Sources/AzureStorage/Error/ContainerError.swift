//
//  ContainerError.swift
//  
//
//  Created by Antwan van Houdt on 21/01/2021.
//

public enum ContainerError: Error {
  case listFailed
  case deleteFailed(_ container: String, error: ErrorEntity?)
  case createFailed(_ container: String, error: ErrorEntity?)
  case unknownError(_ container: String, message: String?)
}
