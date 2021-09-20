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
    return { store, action, lastState in
        switch action {
        case .pairSensor:
            pairingService.pairSensor(completionHandler: { (uuid, patchInfo, fram, streamingEnabled) -> Void in
                let dispatch = store.dispatch
                
                if streamingEnabled {
                    DispatchQueue.main.async {
                        dispatch(.setSensor(value: Sensor(uuid: uuid, patchInfo: patchInfo, fram: fram)))
                        dispatch(.connectSensor)
                    }
                }
            })

        case .connectSensor:
            if let sensor = store.state.sensor {
                connectionService.connectSensor(sensor: sensor, completionHandler: { (update) -> Void in
                    let dispatch = store.dispatch
                    var action: AppAction? = nil
                    
                    if let connectionUpdate = update as? Libre2ConnectionUpdate {
                        action = .setSensorConnection(connectionState: connectionUpdate.connectionState)

                    } else if let readingUpdate = update as? Libre2GlucoseUpdate {
                        action = .setSensorReading(glucose: readingUpdate.glucose)

                    } else if let ageUpdate = update as? Libre2AgeUpdate {
                        action = .setSensorAge(sensorAge: ageUpdate.sensorAge)
                        
                    } else if let errorUpdate = update as? Libre2ErrorUpdate {
                        action = .setSensorError(errorMessage: errorUpdate.errorMessage, errorTimestamp: errorUpdate.errorTimestamp)
                        
                    }
                    
                    if let action = action {
                        DispatchQueue.main.async {
                            dispatch(action)
                        }
                    }
                })
            }

        case .disconnectSensor:
            connectionService.disconnectSensor()

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}
