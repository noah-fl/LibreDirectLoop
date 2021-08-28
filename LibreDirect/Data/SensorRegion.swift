//
//  SensorRegion.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 06.07.21.
//

import Foundation

public enum SensorRegion: String, Codable {
    case unknown = "0 - Unknown"
    case european = "1 - European"
    case usa = "2 - USA"
    case australian = "4 - Australian"
    case eastern = "8 - Eastern"

    public init() {
        self = .unknown
    }

    public init(patchInfo: Data) {
        switch patchInfo[3] {
        case 0:
            self = .unknown
        case 1:
            self = .european
        case 2:
            self = .usa
        case 4:
            self = .australian
        case 8:
            self = .eastern
        default:
            self = .unknown
        }
    }

    public var description: String {
        return self.rawValue
    }
}
