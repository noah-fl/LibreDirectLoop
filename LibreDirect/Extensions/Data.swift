//
//  Data.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 06.07.21.
//

import Foundation

public extension Data {
    var hex: String {
        return map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    func toBase64() -> String {
        return self.base64EncodedString()
    }
}
