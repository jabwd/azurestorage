//
//  String+QueryParams.swift
//  
//
//  Created by Antwan van Houdt on 30/09/2021.
//

import Foundation

extension String {
  mutating func appendWithNewLine(_ str: String?) {
    guard let str = str else {
      append("\n")
      return
    }
    append("\(str)\n")
  }

  var queryParameters: [(key: String, value: String)] {
    let components = self.split(separator: "&")
    var result: [(key: String, value: String)] = []
    result.reserveCapacity(components.count)
    for component in components {
      let separatorIdx = component.firstIndex { $0 == "=" }
      guard let idx = separatorIdx else {
        continue
      }
      let key = String(component[component.startIndex..<idx])
      let value = String(component[component.index(after: idx)..<component.endIndex])
      result.append((key, value))
    }
    return result
  }
}

extension URL {
  var queryParameters: [(key: String, value: String)]? {
    return self.query?.queryParameters
  }
}
