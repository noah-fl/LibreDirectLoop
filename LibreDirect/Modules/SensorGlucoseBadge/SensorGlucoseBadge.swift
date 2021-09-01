//
//  SensorGlucoseBadge.swift
//  LibreDirect
//
//  Created by Reimar Metzen on 24.07.21.
//

import Foundation
import Combine
import UserNotifications
import UIKit

public func sensorGlucoseBadgeMiddelware() -> Middleware<AppState, AppAction> {
    return sensorGlucoseBadgeMiddelware(service: SensorGlucoseBadgeService())
}

func sensorGlucoseBadgeMiddelware(service: SensorGlucoseBadgeService) -> Middleware<AppState, AppAction> {
    return { state, action, lastState in
        switch action {
        case .setSensorReading(glucose: let glucose):
            if state.glucoseUnit == .mgdL {
                service.setGlucoseBadge(glucose: glucose.glucoseFiltered)
            } else {
                service.setGlucoseBadge(glucose: 0)
            }

        default:
            break

        }

        return Empty().eraseToAnyPublisher()
    }
}

class SensorGlucoseBadgeService {
    func setGlucoseBadge(glucose: Int) {
        dispatchPrecondition(condition: .onQueue(DispatchQueue.main))

        NotificationCenterService.shared.ensureCanSendNotification { ensured in
            Log.info("Glucose badge, ensured: \(ensured)")

            guard ensured else {
                return
            }

            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = glucose
            }
        }
    }
}
