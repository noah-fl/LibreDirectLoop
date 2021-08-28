//
//  SensorExpired.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 06.07.21.
//

import Foundation
import Combine
import UserNotifications

public func sensorExpiringAlertMiddelware() -> Middleware<AppState, AppAction> {
    return sensorExpiringAlertMiddelware(service: SensorExpiringAlertService())
}

func sensorExpiringAlertMiddelware(service: SensorExpiringAlertService) -> Middleware<AppState, AppAction> {
    return { state, action, lastState in
        switch action {
        case .setSensorAge(sensorAge: let sensorAge):
            guard let sensor = state.sensor else {
                break
            }

            Log.info("Sensor expiring alert check, age: \(sensorAge)")
            
            let remainingMinutes = max(0, sensor.lifetime - sensorAge)
            if remainingMinutes < 5 { // expired
                Log.info("Sensor expired alert!")
                
                service.sendSensorExpiredNotification()
                
            } else if remainingMinutes <= (8 * 60 + 1) { // less than 8 hours
                Log.info("Sensor expiring alert, less than 8 hours")
                
                if remainingMinutes.inHours == 0 {
                    service.sendSensorExpiringNotification(body: String(format: LocalizedString("Your sensor is about to expire. Replace sensor in %1$@ minutes.", comment: ""), remainingMinutes.inMinutes.description), withSound: true)
                } else {
                    service.sendSensorExpiringNotification(body: String(format: LocalizedString("Your sensor is about to expire. Replace sensor in %1$@ hours.", comment: ""), remainingMinutes.inHours.description), withSound: true)
                }
                
                
            } else if remainingMinutes <= (24 * 60 + 1) { // less than 24 hours
                Log.info("Sensor expiring alert check, less than 24 hours")
                
                service.sendSensorExpiringNotification(body: String(format: LocalizedString("Your sensor is about to expire. Replace sensor in %1$@ hours.", comment: ""), remainingMinutes.inHours.description))
                
            }
                
        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

class SensorExpiringAlertService: NotificationCenterService {
    var nextExpiredAlert: Date? = nil
    var lastExpiringAlert: String = ""
    
    enum Identifier: String {
        case sensorExpiring = "libre-direct.notifications.sensor-expiring-alert"
    }
    
    func clearNotifications() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Identifier.sensorExpiring.rawValue])
    }

    func sendSensorExpiredNotification() {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        
        guard nextExpiredAlert == nil || Date() >= nextExpiredAlert! else {
            return
        }
        
        nextExpiredAlert = Date().addingTimeInterval(AppConfig.ExpiredNotificationInterval)

        ensureCanSendNotification { ensured in
            Log.info("Sensor expired alert, ensured: \(ensured)")
            
            guard ensured else {
                return
            }

            let notification = UNMutableNotificationContent()
            notification.title = LocalizedString("Alert, sensor expired", comment: "")
            notification.body = LocalizedString("Your sensor has expired and needs to be replaced as soon as possible", comment: "")
            notification.sound = UNNotificationSound.init(named: UNNotificationSoundName(rawValue: "alarm.aiff"))

            self.add(identifier: Identifier.sensorExpiring.rawValue, content: notification)
        }
    }
       
    func sendSensorExpiringNotification(body: String, withSound: Bool = false) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))
        
        guard lastExpiringAlert != body else {
            return
        }
        
        guard nextExpiredAlert == nil || Date() >= nextExpiredAlert! else {
            return
        }
        
        lastExpiringAlert = body
        nextExpiredAlert = Date().addingTimeInterval(AppConfig.ExpiredNotificationInterval)

        ensureCanSendNotification { ensured in
            Log.info("Sensor expired alert, ensured: \(ensured)")
            
            guard ensured else {
                return
            }

            let notification = UNMutableNotificationContent()
            notification.title = LocalizedString("Alert, sensor expiring soon", comment: "")
            notification.body = body
            
            if withSound {
                notification.sound = UNNotificationSound.init(named: UNNotificationSoundName(rawValue: "expiring.aiff"))
            }

            self.add(identifier: Identifier.sensorExpiring.rawValue, content: notification)
        }
    }
}
