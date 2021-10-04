//
//  LibreDirectCGMManager.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 06.07.21.
//

import LoopKit
import ShareClient
import HealthKit
import Combine

public class LibreDirectCGMManager: CGMManager {
    init() {
        store = AppStore(initialState: DefaultAppState(), reducer: defaultAppReducer, middlewares: [
                actionLogMiddleware(),
                libre2Middelware(),
                expiringNotificationMiddelware(),
                glucoseNotificationMiddelware(),
                glucoseBadgeMiddelware(),
                connectionNotificationMiddelware(),
                loopMiddleware() { (value) -> Void in
                    guard self.latestReading == nil || self.latestReading?.id != value.id else {
                        return
                    }

                    let loopGlucose = NewGlucoseSample(date: value.startDate, quantity: value.quantity, trend: value.trendType, isDisplayOnly: false, wasUserEntered: false, syncIdentifier: value.id.description, device: self.device)
                    let loopGlucoseResult: CGMReadingResult = .newData([loopGlucose])

                    self.latestReading = value
                    self.delegateQueue.async {
                        self.cgmManagerDelegate?.cgmManager(self, hasNew: loopGlucoseResult)
                    }
                }
            ])
    }

    required convenience public init?(rawState: CGMManager.RawStateValue) {
        self.init()

        if self.store?.state.isPaired ?? false {
            DispatchQueue.global(qos: .utility).async {
                Thread.sleep(forTimeInterval: 3)

                DispatchQueue.main.sync {
                    Log.debug("connectSensor")
                    self.store?.dispatch(.connectSensor)
                }
            }
        }
    }

    let shareManager = ShareClientManager()
    var store: AppStore? = nil
    var latestReading: SensorGlucose?

    public let managerIdentifier: String = "LibreDirect"

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
    public let providesBLEHeartbeat = true
    public let managedDataInterval: TimeInterval? = nil
    public let hasValidSensorSession = true

    public var shouldSyncToRemoteService: Bool {
        return store?.state.nightscoutUpload ?? false
    }

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
            udiDeviceIdentifier: ""
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

