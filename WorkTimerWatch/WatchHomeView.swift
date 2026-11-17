//
//  WatchHomeView.swift
//  WorkTimerWatch
//

import SwiftUI

struct WatchHomeView: View {
    var body: some View {
        TabView {
            WatchTimerView()
                .tabItem { Label("watch.tab.timer".loc, systemImage: "timer") }

            WatchSummaryView()
                .tabItem { Label("watch.tab.summary".loc, systemImage: "chart.bar.fill") }

            WatchAddDayView()
                .tabItem { Label("watch.tab.add".loc, systemImage: "plus.circle.fill") }
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    WatchHomeView().environment(WatchLink.shared)
}
