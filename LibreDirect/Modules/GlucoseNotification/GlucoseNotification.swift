//
//  SensorGlucoseAlert.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 19.07.21.
//

import Foundation
import Combine
import UserNotifications

public func glucoseNotificationMiddelware() -> Middleware<AppState, AppAction> {
    return glucoseNotificationMiddelware(service: glucoseNotificationService())
}

func glucoseNotificationMiddelware(service: glucoseNotificationService) -> Middleware<AppState, AppAction> {
    return { store, action, lastState in
        switch action {
        case .setSensorReading(glucose: let glucose):
            var isSnoozed = false

            if let snoozeUntil = store.state.alarmSnoozeUntil, Date() < snoozeUntil {
                Log.info("Glucose alert snoozed until \(snoozeUntil.localTime)")
                isSnoozed = true
            }

            if glucose.glucoseFiltered < store.state.alarmLow {
                if !isSnoozed {
                    Log.info("Glucose alert, low: \(glucose.glucoseFiltered) < \(store.state.alarmLow)")

                    service.sendLowGlucoseNotification(glucose: glucose.glucoseFiltered.asGlucose(unit: store.state.glucoseUnit))

                    DispatchQueue.main.async {
                        store.dispatch(.setAlarmSnoozeUntil(value: Date().addingTimeInterval(5 * 60).rounded(on: 1, .minute)))
                    }
                }
            } else if glucose.glucoseFiltered > store.state.alarmHigh {
                if !isSnoozed {
                    Log.info("Glucose alert, high: \(glucose.glucoseFiltered) > \(store.state.alarmHigh)")

                    service.sendHighGlucoseNotification(glucose: glucose.glucoseFiltered.asGlucose(unit: store.state.glucoseUnit))

                    DispatchQueue.main.async {
                        store.dispatch(.setAlarmSnoozeUntil(value: Date().addingTimeInterval(5 * 60).rounded(on: 1, .minute)))
                    }
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

class glucoseNotificationService {
    enum Identifier: String {
        case sensorGlucoseAlert = "libre-direct.notifications.sensor-glucose-alert"
    }

    func clearNotifications() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Identifier.sensorGlucoseAlert.rawValue])
    }

    func sendLowGlucoseNotification(glucose: String) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

        NotificationCenterService.shared.ensureCanSendNotification { ensured in
            Log.info("Glucose alert, ensured: \(ensured)")

            guard ensured else {
                return
            }

            let notification = UNMutableNotificationContent()
            notification.title = LocalizedString("Alert, low blood glucose", comment: "")
            notification.body = String(format: LocalizedString("Your blood sugar %1$@ is dangerously low. With sweetened drinks or dextrose, blood glucose levels can often return to normal.", comment: ""), glucose)
            notification.badge = 2.0
            notification.sound = .none

            NotificationCenterService.shared.add(identifier: Identifier.sensorGlucoseAlert.rawValue, content: notification)
            NotificationCenterService.shared.playAlarmSound()
        }
    }

    func sendHighGlucoseNotification(glucose: String) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

        NotificationCenterService.shared.ensureCanSendNotification { ensured in
            Log.info("Glucose alert, ensured: \(ensured)")

            guard ensured else {
                return
            }

            let notification = UNMutableNotificationContent()
            notification.title = LocalizedString("Alert, high blood sugar", comment: "")
            notification.body = String(format: LocalizedString("Your blood sugar %1$@ is dangerously high and needs to be treated.", comment: ""), glucose)
            notification.sound = .none

            NotificationCenterService.shared.add(identifier: Identifier.sensorGlucoseAlert.rawValue, content: notification)
            NotificationCenterService.shared.playAlarmSound()
        }
    }
}
