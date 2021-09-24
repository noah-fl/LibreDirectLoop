//
//  Libre2.swift
//  LibreDirect
//
//  Copyright © 2021 Mark Wilson. All rights reserved.
//

import Foundation
import Combine

fileprivate enum Keys: String {
    case libre2UnlockCount = "libre-direct.libre2.unlock-count"
    case libre2PeripheralUuid = "libre-direct.libre2.peripheral-uuid"
}

extension UserDefaults {
    var libre2UnlockCount: Int {
        get {
            return UserDefaults.standard.integer(forKey: Keys.libre2UnlockCount.rawValue)
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: Keys.libre2UnlockCount.rawValue)
        }
    }

    var libre2PeripheralUuid: String? {
        get {
            return UserDefaults.standard.string(forKey: Keys.libre2PeripheralUuid.rawValue)
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.setValue(newValue, forKey: Keys.libre2PeripheralUuid.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.libre2PeripheralUuid.rawValue)
            }

        }
    }
}

@available(iOS 13.0, *)
public func libre2Middelware() -> Middleware<AppState, AppAction> {
    return libre2Middelware(pairingService: Libre2PairingService(), connectionService: Libre2ConnectionService())
}

@available(iOS 13.0, *)
fileprivate func libre2Middelware(pairingService: Libre2PairingProtocol, connectionService: Libre2ConnectionProtocol) -> Middleware<AppState, AppAction> {
    return { store, action, lastState in
        switch action {
        case .pairSensor:
            pairingService.pairSensor() { (uuid, patchInfo, fram, streamingEnabled) -> Void in
                let dispatch = store.dispatch

                if streamingEnabled {
                    DispatchQueue.main.async {
                        UserDefaults.standard.libre2UnlockCount = 0
                        UserDefaults.standard.libre2PeripheralUuid = nil

                        dispatch(.setSensor(value: Sensor(uuid: uuid, patchInfo: patchInfo, fram: fram)))
                        dispatch(.connectSensor)
                    }
                }
            }

        case .connectSensor:
            if let sensor = store.state.sensor {
                connectionService.connectSensor(sensor: sensor) { (update) -> Void in
                    let dispatch = store.dispatch
                    var action: AppAction? = nil

                    if let connectionUpdate = update as? Libre2ConnectionUpdate {
                        action = .setSensorConnection(connectionState: connectionUpdate.connectionState)

                    } else if let readingUpdate = update as? Libre2GlucoseUpdate {
                        if let glucose = readingUpdate.glucose {
                            action = .setSensorReading(glucose: glucose)
                        } else {
                            action = .setSensorMissedReadings
                        }

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
                }
            }

        case .disconnectSensor:
            connectionService.disconnectSensor()

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}
