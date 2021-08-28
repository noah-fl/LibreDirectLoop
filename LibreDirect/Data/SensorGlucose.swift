//
//  SensorGlucose.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 06.07.21.
//

import Foundation
import HealthKit


public class SensorGlucose: CustomStringConvertible, Codable {
    public let id: Int
    public let timeStamp: Date
    public let glucoseValue: Int
    
    public var lowerLimits: [Int] = [AppConfig.MinReadableGlucose]
    public var upperLimits: [Int] = [AppConfig.MaxReadableGlucose]
    public var minuteChange: Double? = nil
    public var smoothedGlucoseValue: Int? = nil
    
    public var trend: SensorTrend {
        get {
            if let minuteChange = minuteChange {
                return SensorTrend(slope: minuteChange)
            }
            
            return .unknown
        }
    }
    
    public var glucoseFiltered: Int {
        get {
            if let lowerLimit = lowerLimits.max(), glucoseValue < lowerLimit {
                return lowerLimit
            } else if let upperLimit = upperLimits.min(), glucoseValue > upperLimit {
                return upperLimit
            }

            return glucoseValue
        }
    }
    
    private let rawSensorValue: Double?
    private let rawTemperature: Double?
    private let rawTemperatureAdjustment: Double?
    
    public init(glucose: Int) {
        self.id = 0
        self.timeStamp = Date()
        self.glucoseValue = glucose
        self.minuteChange = 0
        self.rawSensorValue = nil
        self.rawTemperature = nil
        self.rawTemperatureAdjustment = nil
    }
    
    public init(timeStamp: Date, glucose: Int) {
        self.id = 0
        self.timeStamp = timeStamp.rounded(on: 1, .minute)
        self.glucoseValue = glucose
        self.minuteChange = 0
        self.rawSensorValue = nil
        self.rawTemperature = nil
        self.rawTemperatureAdjustment = nil
    }

    public init(id: Int, timeStamp: Date, glucose: Int, minuteChange: Double) {
        self.id = id
        self.timeStamp = timeStamp.rounded(on: 1, .minute)
        self.glucoseValue = glucose
        self.minuteChange = minuteChange
        self.rawSensorValue = nil
        self.rawTemperature = nil
        self.rawTemperatureAdjustment = nil
    }

    public init(id: Int, timeStamp: Date, rawSensorValue: Double, rawTemperature: Double, rawTemperatureAdjustment: Double, calibration: SensorCalibration) {
        self.id = id
        self.timeStamp = timeStamp.rounded(on: 1, .minute)
        self.rawSensorValue = rawSensorValue
        self.rawTemperature = rawTemperature
        self.rawTemperatureAdjustment = rawTemperatureAdjustment
        self.glucoseValue = calibration.calibrate(rawValue: rawSensorValue, rawTemperature: rawTemperature, rawTemperatureAdjustment: rawTemperatureAdjustment)
    }

    public var description: String {
        return "\(timeStamp.localTime): \(glucoseFiltered.description) \(trend.description) (kalman: \(smoothedGlucoseValue), lowerLimits: \(lowerLimits), upperLimits: \(upperLimits))"
    }
}

fileprivate extension Sequence where Element: SensorGlucose {
    func sum() -> Double {
        return Double(self.compactMap { $0.glucoseValue }.reduce(0, +))
    }
}
