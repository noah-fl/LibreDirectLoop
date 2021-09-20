//
//  SensorConnection.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 06.07.21.
//

import Foundation
import Combine
import CoreBluetooth

class Libre2Update {
}

class Libre2AgeUpdate: Libre2Update {
    private(set) var sensorAge: Int

    init(sensorAge: Int) {
        self.sensorAge = sensorAge
    }
}

class Libre2ConnectionUpdate: Libre2Update {
    private(set) var connectionState: SensorConnectionState

    init(connectionState: SensorConnectionState) {
        self.connectionState = connectionState
    }
}

class Libre2GlucoseUpdate: Libre2Update {
    private(set) var glucose: SensorGlucose

    init(lastGlucose: SensorGlucose) {
        self.glucose = lastGlucose
    }
}

class Libre2ErrorUpdate: Libre2Update {
    private(set) var errorMessage: String
    private(set) var errorTimestamp: Date = Date()

    init(errorMessage: String) {
        self.errorMessage = errorMessage
    }

    init(errorCode: Int) {
        self.errorMessage = translateError(errorCode: errorCode)
    }
}

typealias Libre2ConnectionHandler = (_ update: Libre2Update) -> Void

protocol Libre2ConnectionProtocol {
    func connectSensor(sensor: Sensor, completionHandler: @escaping Libre2ConnectionHandler)
    func disconnectSensor()
}

class Libre2ConnectionService: NSObject, Libre2ConnectionProtocol {
    private let expectedBufferSize = 46
    private var rxBuffer = Data()

    private var completionHandler: Libre2ConnectionHandler?

    private var manager: CBCentralManager! = nil
    private let managerQueue: DispatchQueue = DispatchQueue(label: "libre-direct.ble-queue") // , qos: .unspecified

    private var abbottServiceUuid: [CBUUID] = [CBUUID(string: "FDE3")]
    private var bleLoginUuid: CBUUID = CBUUID(string: "F001")
    private var compositeRawDataUuid: CBUUID = CBUUID(string: "F002")
    private var libre3DataUuid = CBUUID(string: "089810CC-EF89-11E9-81B4-2A2AE2DBCCE4")

    private var readCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?

    private var stayConnected = false
    private var sensor: Sensor? = nil
    private var lastGlucose: SensorGlucose? = nil
    private var kalmanInstance: KalmanFilter = KalmanFilter()

    private var peripheral: CBPeripheral? {
        didSet {
            oldValue?.delegate = nil
            peripheral?.delegate = self
        }
    }

    override init() {
        super.init()

        manager = CBCentralManager(delegate: self, queue: managerQueue, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    func connectSensor(sensor: Sensor, completionHandler: @escaping Libre2ConnectionHandler) {
        dispatchPrecondition(condition: .notOnQueue(managerQueue))

        Log.info("ConnectSensor: \(sensor)")
        
        self.completionHandler = completionHandler
        self.sensor = sensor

        managerQueue.async {
            self.scan()
        }
    }

    func disconnectSensor() {
        dispatchPrecondition(condition: .notOnQueue(managerQueue))

        Log.info("DisconnectSensor")

        self.sensor = nil
        self.lastGlucose = nil

        managerQueue.sync {
            self.disconnect()
        }
    }

    private func scan() {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("Scan")

        guard sensor != nil else {
            return
        }

        setStayConnected(stayConnected: true)

        guard manager.state == .poweredOn else {
            return
        }

        if manager.isScanning {
            manager.stopScan()
        }

        sendUpdate(connectionState: .scanning)
        manager.scanForPeripherals(withServices: abbottServiceUuid, options: nil)
    }

    private func disconnect() {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("Disconnect")

        setStayConnected(stayConnected: false)

        if manager.isScanning {
            manager.stopScan()
        }

        if let peripheral = peripheral {
            manager.cancelPeripheralConnection(peripheral)
        } else {
            sendUpdate(connectionState: .disconnected)
        }
    }
    
    private func connect() {
        if let peripheral = self.peripheral {
            connect(peripheral)
        }
    }

    private func connect(_ peripheral: CBPeripheral) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("Connect: \(peripheral)")

        if manager.isScanning {
            manager.stopScan()
        }

        self.peripheral = peripheral
        manager.connect(peripheral, options: nil)
        
        sendUpdate(connectionState: .connecting)
    }

    private func unlock() -> Data? {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("Unlock")

        if sensor == nil {
            return nil
        }

        sensor!.unlockCount = sensor!.unlockCount + 1

        let unlockPayload = Libre2.streamingUnlockPayload(sensorUID: sensor!.uuid, info: sensor!.patchInfo, enableTime: 42, unlockCount: UInt16(sensor!.unlockCount))
        return Data(unlockPayload)
    }

    private func resetBuffer() {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("ResetBuffer")

        rxBuffer = Data()
    }

    private func setStayConnected(stayConnected: Bool) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("StayConnected: \(stayConnected.description)")

        self.stayConnected = stayConnected
    }

    private func sendUpdate(connectionState: SensorConnectionState) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("ConnectionState: \(connectionState.description)")

        self.completionHandler?(Libre2ConnectionUpdate(connectionState: connectionState))
    }

    private func sendUpdate(sensorAge: Int) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("SensorAge: \(sensorAge.description)")
        self.completionHandler?(Libre2AgeUpdate(sensorAge: sensorAge))
    }

    private func sendUpdate(glucose: SensorGlucose) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        glucose.smoothedGlucoseValue = Int(round(kalmanInstance.filter(measurement: Double(glucose.glucoseValue))))
        
        if let lastGlucose = lastGlucose {
            glucose.minuteChange = calculateSlope(secondLast: lastGlucose, last: glucose)
        }

        Log.info("Glucose: \(glucose.description)")
        
        lastGlucose = glucose
        self.completionHandler?(Libre2GlucoseUpdate(lastGlucose: glucose))
    }

    private func sendUpdate(error: Error?) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        guard let error = error else {
            return
        }

        Log.error("Error: \(error.localizedDescription)")
        sendUpdate(errorMessage: error.localizedDescription)
    }

    private func sendUpdate(errorMessage: String) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.error("ErrorMessage: \(errorMessage)")
        self.completionHandler?(Libre2ErrorUpdate(errorMessage: errorMessage))
    }

    private func sendUpdate(errorCode: Int) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.error("ErrorCode: \(errorCode)")
        self.completionHandler?(Libre2ErrorUpdate(errorCode: errorCode))
    }
}

extension Libre2ConnectionService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("State: \(manager.state.rawValue)")

        switch manager.state {
        case .poweredOff:
            sendUpdate(connectionState: .powerOff)

        case .poweredOn:
            sendUpdate(connectionState: .disconnected)

            if stayConnected {
                scan()
            }
        default:
            sendUpdate(connectionState: .unknown)

        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("Peripheral: \(peripheral)")

        guard let sensor = sensor, let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else {
            return
        }

        Log.info("Sensor: \(sensor)")
        Log.info("ManufacturerData: \(manufacturerData)")

        if manufacturerData.count == 8 {
            var foundUUID = manufacturerData.subdata(in: 2..<8)
            foundUUID.append(contentsOf: [0x07, 0xe0])

            let result = foundUUID == sensor.uuid && peripheral.name?.lowercased().starts(with: "abbott") ?? false
            if result {
                connect(peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("Peripheral: \(peripheral)")

        peripheral.discoverServices(abbottServiceUuid)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("Peripheral: \(peripheral)")
        sendUpdate(connectionState: .disconnected)
        sendUpdate(error: error)

        guard stayConnected else {
            return
        }

        connect()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("Peripheral: \(peripheral)")
        sendUpdate(connectionState: .disconnected)
        sendUpdate(error: error)

        guard stayConnected else {
            return
        }

        connect()
    }
}

extension Libre2ConnectionService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("Peripheral: \(peripheral)")
        sendUpdate(error: error)

        if let services = peripheral.services {
            for service in services {
                Log.info("Service Uuid: \(service.uuid)")

                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("Peripheral: \(peripheral)")
        sendUpdate(error: error)

        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                Log.info("Characteristic Uuid: \(characteristic.uuid.description)")

                if characteristic.uuid == compositeRawDataUuid {
                    readCharacteristic = characteristic
                }

                if characteristic.uuid == bleLoginUuid {
                    writeCharacteristic = characteristic

                    if let unlock = unlock() {
                        peripheral.writeValue(unlock, for: characteristic, type: .withResponse)
                    }
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("Peripheral: \(peripheral)")
        sendUpdate(error: error)
        sendUpdate(connectionState: .connected)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("Peripheral: \(peripheral)")
        sendUpdate(error: error)

        if characteristic.uuid == bleLoginUuid {
            peripheral.setNotifyValue(true, for: readCharacteristic!)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        dispatchPrecondition(condition: .onQueue(managerQueue))

        Log.info("Peripheral: \(peripheral)")
        sendUpdate(error: error)

        guard let value = characteristic.value else {
            return
        }

        rxBuffer.append(value)

        if rxBuffer.count == expectedBufferSize {
            if let sensor = sensor {
                do {
                    let decryptedBLE = Data(try Libre2.decryptBLE(sensorUID: sensor.uuid, data: rxBuffer))
                    let sensorUpdate = Libre2.parseBLEData(decryptedBLE, calibration: sensor.calibration)

                    sendUpdate(sensorAge: sensorUpdate.age)
                    
                    if let newestGlucose = sensorUpdate.trend.last {
                        sendUpdate(glucose: newestGlucose)
                    }
                    
                    resetBuffer()
                } catch {
                    resetBuffer()
                }
            }
        }
    }
}

fileprivate func translateError(errorCode: Int) -> String {
    switch errorCode {
    case 0: //case unknown = 0
        return "unknown"

    case 1: //case invalidParameters = 1
        return "invalidParameters"

    case 2: //case invalidHandle = 2
        return "invalidHandle"

    case 3: //case notConnected = 3
        return "notConnected"

    case 4: //case outOfSpace = 4
        return "outOfSpace"

    case 5: //case operationCancelled = 5
        return "operationCancelled"

    case 6: //case connectionTimeout = 6
        return "connectionTimeout"

    case 7: //case peripheralDisconnected = 7
        return "peripheralDisconnected"

    case 8: //case uuidNotAllowed = 8
        return "uuidNotAllowed"

    case 9: //case alreadyAdvertising = 9
        return "alreadyAdvertising"

    case 10: //case connectionFailed = 10
        return "connectionFailed"

    case 11: //case connectionLimitReached = 11
        return "connectionLimitReached"

    case 13: //case operationNotSupported = 13
        return "operationNotSupported"

    default:
        return ""
    }
}

fileprivate class KalmanFilter {
    /// Set the process noise R
    var processNoise: Double
    
    /// measurement noise Q
    var measurementNoise: Double
    
    private let stateVector: Double
    private let controlVector: Double
    private let measurementVector: Double
    
    private var covariance: Double? = nil
    private var estimatedSignal: Double? = nil
    
    /// Create 1-dimensional kalman filter
    ///
    /// - Parameters:
    ///   - processNoise: Process noise
    ///   - measurementNoise: Measurement noise
    ///   - stateVector: State vector
    ///   - controlVector: Control vector
    ///   - measurementVector: Measurement vector
    init(processNoise: Double = 1.0, measurementNoise: Double = 1.0, stateVector: Double = 1.0, controlVector: Double = 0.0, measurementVector: Double = 1) {
        self.processNoise = processNoise
        self.measurementNoise = measurementNoise
        self.stateVector = stateVector
        self.controlVector = controlVector
        self.measurementVector = measurementVector
    }
    
    /// Filter a new value
    ///
    /// - Parameters:
    ///   - measurement: Measurement
    ///   - control: Control
    /// - Returns: New filter value
    func filter(measurement: Double, control: Int = 0) -> Double {
        if (self.estimatedSignal == nil) {
            self.estimatedSignal = (1 / self.measurementVector) * measurement
            self.covariance = (1 / self.measurementVector) * self.measurementNoise * (1 / self.measurementVector)
        } else {
            // Compute prediction
            let predSignal = self.predict(control: control)!
            let predCov = self.uncertainty!
            
            // Kalman gain
            let gain = predCov * self.measurementVector * (1 / ((self.measurementVector * predCov * self.measurementVector) + self.measurementNoise))
            
            // Correction
            self.estimatedSignal = predSignal + gain * (measurement - (self.measurementVector * predSignal))
            self.covariance = predCov - (gain * self.measurementVector * predCov)
        }
        return self.estimatedSignal!
    }
    
    /// Predict next value
    ///
    /// - Parameter control: Control
    /// - Returns: Predicted value
    func predict(control: Int = 0) -> Double? {
        guard let estimation = self.estimatedSignal else {
            // Return nil if there is no estimation set
            return nil
        }
        return (self.stateVector * estimation) + (self.controlVector * Double(control))
    }
    
    /// Return uncertainty of filter. `nil` in case no covariance was set.
    var uncertainty: Double? {
        guard let cov = self.covariance else {
            return nil
        }
        return ((self.stateVector * cov) * self.stateVector) + self.processNoise
    }
    
    /// last filtered measurement
    var lastMeasurement: Double? {
        return self.estimatedSignal
    }
}

fileprivate func calculateDiffInMinutes(secondLast: Date, last: Date) -> Double {
    let diff = last.timeIntervalSince(secondLast)
    return diff / 60
}

fileprivate func calculateSlope(secondLast: SensorGlucose, last: SensorGlucose) -> Double {
    if secondLast.timestamp == last.timestamp {
        return 0.0
    }

    let glucoseDiff = Double(last.glucoseValue) - Double(secondLast.glucoseValue)
    let minutesDiff = calculateDiffInMinutes(secondLast: secondLast.timestamp, last: last.timestamp)

    return glucoseDiff / minutesDiff
}
