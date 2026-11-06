//
//  WatchHomeView.swift
//  WorkTimerWatch
//

import SwiftUI

struct WatchHomeView: View {
    var body: some View {
        TabView {
            WatchTimerView()
                .tabItem { Label("Chrono", systemImage: "timer") }

            WatchSummaryView()
                .tabItem { Label("Résumé", systemImage: "chart.bar.fill") }

            WatchAddDayView()
                .tabItem { Label("Ajouter", systemImage: "plus.circle.fill") }
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    WatchHomeView().environment(WatchLink.shared)
}
