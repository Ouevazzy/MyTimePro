//
//  WatchTimerView.swift
//  WorkTimerWatch
//
//  Chrono en direct : pointer arrivée / pause / départ depuis le poignet.
//

import SwiftUI

struct WatchTimerView: View {
    @Environment(WatchLink.self) private var link

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if link.timerActive {
                    activeContent
                } else {
                    idleContent
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Chrono")
    }

    private var idleContent: some View {
        VStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.system(size: 34))
                .foregroundStyle(.blue)
            Button {
                link.startTimer()
            } label: {
                Label("Pointer l'arrivée", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    private var activeContent: some View {
        VStack(spacing: 10) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let now = context.date
                VStack(spacing: 2) {
                    Text(WatchFormat.elapsed(link.workedSeconds(at: now)))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(link.timerPaused ? .orange : .green)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    let brk = link.breakSeconds(at: now)
                    if brk >= 60 || link.timerPaused {
                        Text("Pause \(WatchFormat.elapsed(brk))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: 8) {
                Button {
                    if link.timerPaused { link.resumeTimer() } else { link.pauseTimer() }
                } label: {
                    Image(systemName: link.timerPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Button {
                    link.stopTimer()
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            if !link.isReachable {
                Text("iPhone hors de portée — enregistré à la reconnexion")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    WatchTimerView().environment(WatchLink.shared)
}
