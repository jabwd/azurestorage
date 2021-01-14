//
//  Signature.swift
//  
//
//  Created by Antwan van Houdt on 14/01/2021.
//
//  Helper functions for generating a valid Authorization signature
//  string for azure storage using a shared key

import Vapor

extension String {
    mutating func appendWithNewLine(_ str: String?) {
        guard let str = str else {
            self.append("\n")
            return
        }
        self.append("\(str)\n")
    }

    var queryParameters: [(key: String, value: String)] {
        let components = self.split(separator: "&")
        var result: [(key: String, value: String)] = []
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

extension Date {
    var xMSDateFormat: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss z"
        formatter.timeZone = TimeZone.init(secondsFromGMT: 0)
        return formatter.string(from: Date())
    }
}
