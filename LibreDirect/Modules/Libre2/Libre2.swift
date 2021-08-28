//
//  Libre2.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 27.08.21.
//  Copyright © 2021 Mark Wilson. All rights reserved.
//

import Foundation
import Combine

@available(iOS 13.0, *)
public func libre2Middelware() -> Middleware<AppState, AppAction> {
    return libre2Middelware(pairingService: Libre2PairingService(), connectionService: Libre2ConnectionService())
}

@available(iOS 13.0, *)
fileprivate func libre2Middelware(pairingService: Libre2PairingProtocol, connectionService: Libre2ConnectionProtocol) -> Middleware<AppState, AppAction> {
    return { state, action, lastState in
        switch action {
        case .pairSensor:
            return pairingService.pairSensor()
                .subscribe(on: DispatchQueue.main)
                .map { AppAction.setSensor(value: Sensor(uuid: $0.uuid, patchInfo: $0.patchInfo, fram: $0.fram)) }
                .eraseToAnyPublisher()

        case .subscribeForUpdates:
            return connectionService.subscribeForUpdates()
                .subscribe(on: DispatchQueue.main)
                .map {
                if let connectionUpdate = $0 as? Libre2ConnectionUpdate {
                    return AppAction.setSensorConnection(connectionState: connectionUpdate.connectionState)

                } else if let readingUpdate = $0 as? Libre2GlucoseUpdate {
                    return AppAction.setSensorReading(glucose: readingUpdate.glucose)

                } else if let ageUpdate = $0 as? Libre2AgeUpdate {
                    return AppAction.setSensorAge(sensorAge: ageUpdate.sensorAge)

                } else if let errorUpdate = $0 as? Libre2ErrorUpdate {
                    return AppAction.setSensorError(errorMessage: errorUpdate.errorMessage, errorTimestamp: errorUpdate.errorTimestamp)
                }

                return AppAction.setSensorError(errorMessage: "Unknown error", errorTimestamp: Date())
            }.eraseToAnyPublisher()

        case .connectSensor:
            if let sensor = state.sensor {
                connectionService.connectSensor(sensor: sensor)
            }

        case .disconnectSensor:
            connectionService.disconnectSensor()

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}
