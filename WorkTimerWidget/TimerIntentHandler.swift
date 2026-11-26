//
//  TimerIntentHandler.swift
//  WorkTimerWidget
//
//  Les intentions du chrono s'exécutent dans l'app (voir TimerIntents.swift).
//  Côté widget, le type doit exister pour compiler, mais n'a rien à faire.
//

import Foundation

enum TimerIntentHandler {
    static func perform(_ action: TimerWidgetAction) async {}
}
