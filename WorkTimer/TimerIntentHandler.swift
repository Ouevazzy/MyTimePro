//
//  TimerIntentHandler.swift
//  WorkTimer
//
//  Exécute dans l'app les commandes du widget « Chrono » et du Centre de contrôle.
//

import Foundation
import SwiftData

/// Conteneur SwiftData de l'app, pour les intentions lancées sans interface.
@MainActor
enum AppModelContainer {
    static var shared: ModelContainer?
}

enum TimerIntentHandler {
    @MainActor
    static func perform(_ action: TimerWidgetAction) async {
        perform(action, timer: .shared, container: AppModelContainer.shared)
    }

    @MainActor
    static func perform(_ action: TimerWidgetAction, timer: TimerManager, container: ModelContainer?, at now: Date = Date()) {
        switch action {
        case .start:
            timer.start(at: now)
        case .pause:
            timer.pause(at: now)
        case .resume:
            timer.resume(at: now)
        case .stop:
            guard timer.isActive else { return }
            if let container {
                // Plus de 24 h : la session reste ouverte, l'app proposera de corriger l'heure de fin.
                timer.stopAndSave(in: container.mainContext, at: now)
            } else {
                // Sans conteneur, l'app clôturera la session à son ouverture, comme avec Siri.
                UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "siri_timer_stop_time")
                UserDefaults.standard.set(true, forKey: "siri_should_stop_timer")
            }
        }
        timer.publishSharedState()
    }
}
