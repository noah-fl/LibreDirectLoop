//
//  SensorConnectionLostAlert.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 29.07.21.
//

import Foundation
import Combine
import UserNotifications

public func sensorConnectionAlertMiddelware() -> Middleware<AppState, AppAction> {
    return sensorConnectionAlertMiddelware(service: SensorConnectionAlertService())
}

func sensorConnectionAlertMiddelware(service: SensorConnectionAlertService) -> Middleware<AppState, AppAction> {
    return { state, action, lastState in
        switch action {
        case .setSensorConnection(connectionState: let connectionState):
            Log.info("Sensor connection lost alert check: \(connectionState)")

            if lastState.connectionState == .connected && connectionState == .disconnected {
                service.sendSensorConnectionLostNotification()
            } else if lastState.connectionState != .connected && connectionState == .connected {
                service.sendSensorConnectionRestoredNotification()
            }

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

class SensorConnectionAlertService: NotificationCenterService {
    enum Identifier: String {
        case sensorConnectionLost = "libre-direct.notifications.sensor-connection-lost"
    }
    
    func clearNotifications() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Identifier.sensorConnectionLost.rawValue])
    }
    
    func sendSensorConnectionLostNotification() {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        
        ensureCanSendNotification { ensured in
            Log.info("Sensor connection lLost alert, ensured: \(ensured)")
            
            guard ensured else {
                return
            }

            let notification = UNMutableNotificationContent()
            notification.title = LocalizedString("Alert, sensor connection lost", comment: "")
            notification.body = LocalizedString("The connection with the sensor has been lost. Normally this happens when the sensor is outside the possible range.", comment: "")
            notification.sound = UNNotificationSound.init(named: UNNotificationSoundName(rawValue: "negative.aiff"))

            self.add(identifier: Identifier.sensorConnectionLost.rawValue, content: notification)
        }
    }

    func sendSensorConnectionRestoredNotification() {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        
        ensureCanSendNotification { ensured in
            Log.info("Sensor connection lLost alert, ensured: \(ensured)")
            
            guard ensured else {
                return
            }

            let notification = UNMutableNotificationContent()
            notification.title = LocalizedString("OK, sensor connection established", comment: "")
            notification.body = LocalizedString("The connection to the sensor has been successfully established and glucose data is received.", comment: "")
            notification.sound = UNNotificationSound.init(named: UNNotificationSoundName(rawValue: "positive.aiff"))

            self.add(identifier: Identifier.sensorConnectionLost.rawValue, content: notification)
        }
    }
}
