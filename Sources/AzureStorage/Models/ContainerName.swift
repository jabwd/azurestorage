//
//  ContainerName.swift
//  
//
//  Created by Antwan van Houdt on 02/10/2021.
//

import Foundation

public struct ContainerName: Equatable {
  public let value: String

  public init(unsafeName: String) {
    self.value = unsafeName
  }

  public init?(_ name: String) {
    let name = name.lowercased()

    var characterSet = NSCharacterSet.alphanumerics
    characterSet.insert("-")

    var lastHyphen: Int = 0
    for (index, character) in name.enumerated() {
      for scalar in character.unicodeScalars {
        guard characterSet.contains(scalar) else {
          return nil
        }
      }

      if character == "-" {
        if index == 0 || index == (name.count - 1) {
          return nil
        }
        if (lastHyphen + 1) == index {
          return nil
        }
        lastHyphen = index
      }
    }
    self.value = name
  }
}
