//
//  Loop.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 27.08.21.
//  Copyright © 2021 Mark Wilson. All rights reserved.
//

import Foundation
import LoopKit
import HealthKit

extension SensorGlucose : GlucoseValue {
    public var quantity: HKQuantity {
        let unit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
        return HKQuantity(unit: unit, doubleValue: Double(glucoseFiltered))
    }
    
    public var startDate: Date {
        return timeStamp
    }
}

extension SensorGlucose : GlucoseDisplayable {
    public var isStateValid: Bool {
        return true
    }

    public var trendType: GlucoseTrend? {
        if let minuteChange = minuteChange {
            switch minuteChange {
            case _ where minuteChange <= (-3.5): return GlucoseTrend(rawValue: 7)
            case _ where minuteChange <= (-2.0): return GlucoseTrend(rawValue: 6)
            case _ where minuteChange <= (-1.0): return GlucoseTrend(rawValue: 5)
            case _ where minuteChange <= (+1.0): return GlucoseTrend(rawValue: 4)
            case _ where minuteChange <= (+2.0): return GlucoseTrend(rawValue: 3)
            case _ where minuteChange <= (+3.5): return GlucoseTrend(rawValue: 2)
            case _ where minuteChange <= (+4.0): return GlucoseTrend(rawValue: 1)
            default: return GlucoseTrend(rawValue: 4)
            }
        }
        
        return GlucoseTrend(rawValue: 4)
    }
    
    public var isLocal: Bool {
        return true
    }
    
    public var glucoseRangeCategory: GlucoseRangeCategory? {
        return .none
    }
}
