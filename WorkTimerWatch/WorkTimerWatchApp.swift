//
//  WorkTimerWatchApp.swift
//  WorkTimerWatch
//

import SwiftUI

@main
struct WorkTimerWatchApp: App {
    @State private var link = WatchLink.shared

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environment(link)
                .onAppear { link.activate() }
        }
    }
}
