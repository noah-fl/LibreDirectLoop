//
//  G4CGMManager.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKit
import ShareClient
import HealthKit
import Combine

public class LibreDirectCGMManager: CGMManager {
    private var cancellable: AnyCancellable?

    required convenience public init?(rawState: CGMManager.RawStateValue) {
        self.init()

        store.dispatch(.subscribeForUpdates)

        if self.store.state.isPaired {
            DispatchQueue.global(qos: .utility).async {
                Thread.sleep(forTimeInterval: 3)

                DispatchQueue.main.sync {
                    Log.debug("connectSensor")
                    self.store.dispatch(.connectSensor)
                }
            }
        }

        cancellable = store.$state.receive(on: self.delegateQueue).sink { state in
            if let lastGlucose = state.lastGlucose {
                guard self.latestReading == nil || self.latestReading?.id != lastGlucose.id else {
                    return
                }

                let loopGlucose = NewGlucoseSample(date: lastGlucose.startDate, quantity: lastGlucose.quantity, trend: lastGlucose.trendType, isDisplayOnly: false, wasUserEntered: false, syncIdentifier: lastGlucose.id.description, device: self.device)
                let loopGlucoseResult: CGMReadingResult = .newData([loopGlucose])

                self.latestReading = lastGlucose
                self.delegateQueue.async {
                    self.cgmManagerDelegate?.cgmManager(self, hasNew: loopGlucoseResult)
                }
            }
        }
    }

    public let managerIdentifier: String = "LibreDirect"

    let store: AppStore = AppStore(initialState: DefaultAppState(), reducer: defaultAppReducer, middlewares: [
            libre2Middelware(),
            sensorExpiringAlertMiddelware(),
            sensorGlucoseAlertMiddelware(),
            sensorGlucoseBadgeMiddelware(),
            sensorConnectionAlertMiddelware(),
            actionLogMiddleware()
        ])

    var latestReading: SensorGlucose?

    public var rawState: CGMManager.RawStateValue {
        return [:]
    }

    public var cgmManagerDelegate: CGMManagerDelegate? {
        get {
            return shareManager.cgmManagerDelegate
        }
        set {
            shareManager.cgmManagerDelegate = newValue
        }
    }

    public var delegateQueue: DispatchQueue! {
        get {
            return shareManager.delegateQueue
        }
        set {
            shareManager.delegateQueue = newValue
        }
    }

    public let localizedTitle = NSLocalizedString("LibreDirect", comment: "CGM display title")
    public let isOnboarded = true // No distinction between created and onboarded
    public let shouldSyncToRemoteService = false
    public let providesBLEHeartbeat = true
    public let managedDataInterval: TimeInterval? = nil
    public let hasValidSensorSession = true

    let shareManager = ShareClientManager()

    public var glucoseDisplay: GlucoseDisplayable? {
        return latestReading
    }

    public var cgmManagerStatus: CGMManagerStatus {
        return CGMManagerStatus(hasValidSensorSession: hasValidSensorSession)
    }

    public func fetchNewDataIfNeeded(_ completion: @escaping (CGMReadingResult) -> Void) {
        completion(.noData)
    }

    public var device: HKDevice? {
        return HKDevice(
            name: "LibreDirect",
            manufacturer: "Abbott",
            model: "Libre 2",
            hardwareVersion: nil,
            firmwareVersion: nil,
            softwareVersion: String(LibreDirectVersionNumber),
            localIdentifier: nil,
            udiDeviceIdentifier: "40386270000048"
        )
    }

    public var debugDescription: String {
        return [
            "## LibreDirect",
            ""
        ].joined(separator: "\n")
    }
}

// MARK: - AlertResponder implementation
extension LibreDirectCGMManager {
    public func acknowledgeAlert(alertIdentifier: Alert.AlertIdentifier, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
}

// MARK: - AlertSoundVendor implementation
extension LibreDirectCGMManager {
    public func getSoundBaseURL() -> URL? { return nil }
    public func getSounds() -> [Alert.Sound] { return [] }
}
