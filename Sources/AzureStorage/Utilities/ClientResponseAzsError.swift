//
//  ClientResponseAzsError.swift
//  
//
//  Created by Antwan van Houdt on 06/03/2021.
//

import Vapor
import XMLParsing

extension ClientResponse {
  /// Returns the AZS ErrorEntity if a body exists on the given ClientResponse
  /// nil if no body exists or decoding the error body fails
  var azsError: ErrorEntity? {
    guard var body = self.body, body.readableBytes > 0 else {
      return nil
    }
    guard let data = body.readData(length: body.readableBytes) else {
      return nil
    }
    do {
      let decoder = XMLDecoder()
      let response = try decoder.decode(ErrorEntity.self, from: data)
      return response
    } catch {
      return nil
    }
  }
}
