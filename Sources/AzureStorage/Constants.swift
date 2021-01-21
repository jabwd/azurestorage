//
//  Constants.swift
//
//  Created by Antwan van Houdt on 14/01/2021.
//

struct AZS {
    static let version: String = "2019-07-07"

    static let canonicalPrefix = "x-ms"

    /// The date header value needs to be within 15 minutes of the current time of the request being
    /// handled by the blobstorage server
    static let dateHeader = "x-ms-date"

    /// This header indicates some specific quirks on the protocol itself, this project currently
    /// only aims to be compatible with the latest few versions
    static let versionHeader = "x-ms-version"
}
