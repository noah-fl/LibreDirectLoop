//
//  AppAction.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 06.07.21.
//

import Foundation

public enum AppAction {
    case connectSensor
    case disconnectSensor
    case pairSensor
    case resetSensor

    case setSensor(value: Sensor)
    case setSensorConnection(connectionState: SensorConnectionState)
    case setSensorReading(glucose: SensorGlucose)
    case setSensorAge(sensorAge: Int)
    case setSensorError(errorMessage: String, errorTimestamp: Date)

    case setNightscoutHost(host: String)
    case setNightscoutSecret(apiSecret: String)
    
    case setAlarmLow(value: Int)
    case setAlarmHigh(value: Int)
    case setAlarmSnoozeUntil(value: Date?)
    
    case setGlucoseUnit(value: GlucoseUnit)

    case subscribeForUpdates
}
