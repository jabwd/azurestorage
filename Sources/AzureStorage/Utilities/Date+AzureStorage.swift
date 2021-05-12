//
//  Date+AzureStorage.swift
//  
//
//  Created by Antwan van Houdt on 12/05/2021.
//

import Foundation

extension DateFormatter {
  static var xMSDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
    formatter.timeZone = TimeZone.init(secondsFromGMT: 0)
    return formatter
  }()
}

extension Date {
  var xMSDateFormat: String {
    return DateFormatter.xMSDateFormatter.string(from: self)
  }
}
