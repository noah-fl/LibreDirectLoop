//
//  SensorGlucoseAlert.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 19.07.21.
//

import Foundation
import Combine
import UserNotifications

public func sensorGlucoseAlertMiddelware() -> Middleware<AppState, AppAction> {
    return sensorGlucoseAlertMiddelware(service: SensorGlucoseAlertService())
}

func sensorGlucoseAlertMiddelware(service: SensorGlucoseAlertService) -> Middleware<AppState, AppAction> {
    return { state, action, lastState in
        switch action {
        case .setSensorReading(glucose: let glucose):
            var isSnoozed = false

            if let snoozeUntil = state.alarmSnoozeUntil, Date() < snoozeUntil {
                Log.info("Glucose alert snoozed until \(snoozeUntil.localTime)")
                isSnoozed = true
            }

            if glucose.glucoseFiltered < state.alarmLow {
                if !isSnoozed {
                    Log.info("Glucose alert, low: \(glucose.glucoseFiltered) < \(state.alarmLow)")

                    service.sendLowGlucoseNotification(glucose: glucose.glucoseFiltered.asGlucose(unit: state.glucoseUnit))
                    return Just(AppAction.setAlarmSnoozeUntil(value: Date().addingTimeInterval(5 * 60).rounded(on: 1, .minute))).eraseToAnyPublisher()
                }
            } else if glucose.glucoseFiltered > state.alarmHigh {
                if !isSnoozed {
                    Log.info("Glucose alert, high: \(glucose.glucoseFiltered) > \(state.alarmHigh)")

                    service.sendHighGlucoseNotification(glucose: glucose.glucoseFiltered.asGlucose(unit: state.glucoseUnit))
                    return Just(AppAction.setAlarmSnoozeUntil(value: Date().addingTimeInterval(5 * 60).rounded(on: 1, .minute))).eraseToAnyPublisher()
                }
            } else {
                service.clearNotifications()
            }

        default:
            break

        }

        return Empty().eraseToAnyPublisher()
    }
}

class SensorGlucoseAlertService: NotificationCenterService {
    enum Identifier: String {
        case sensorGlucoseAlert = "libre-direct.notifications.sensor-glucose-alert"
    }
    
    func clearNotifications() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Identifier.sensorGlucoseAlert.rawValue])
    }

    func sendLowGlucoseNotification(glucose: String) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

        ensureCanSendNotification { ensured in
            Log.info("Glucose alert, ensured: \(ensured)")

            guard ensured else {
                return
            }
            
            let notification = UNMutableNotificationContent()
            notification.title = LocalizedString("Alert, low blood glucose", comment: "")
            notification.body = String(format: LocalizedString("Your blood sugar %1$@ is dangerously low. With sweetened drinks or dextrose, blood glucose levels can often return to normal.", comment: ""), glucose)
            notification.sound = UNNotificationSound.init(named: UNNotificationSoundName(rawValue: "alarm.aiff"))

            self.add(identifier: Identifier.sensorGlucoseAlert.rawValue, content: notification)
        }
    }

    func sendHighGlucoseNotification(glucose: String) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

        ensureCanSendNotification { ensured in
            Log.info("Glucose alert, ensured: \(ensured)")

            guard ensured else {
                return
            }

            let notification = UNMutableNotificationContent()
            notification.title = LocalizedString("Alert, high blood sugar", comment: "")
            notification.body = String(format: LocalizedString("Your blood sugar %1$@ is dangerously high and needs to be treated.", comment: ""), glucose)
            notification.sound = UNNotificationSound.init(named: UNNotificationSoundName(rawValue: "alarm.aiff"))

            self.add(identifier: Identifier.sensorGlucoseAlert.rawValue, content: notification)
        }
    }
}
