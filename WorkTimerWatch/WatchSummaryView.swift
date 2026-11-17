//
//  WatchSummaryView.swift
//  WorkTimerWatch
//

import SwiftUI

struct WatchSummaryView: View {
    @Environment(WatchLink.self) private var link

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                summaryRow(
                    title: "watch.summary.overtime".loc,
                    value: WatchFormat.signedHours(seconds: link.overtimeSeconds, decimal: link.useDecimalHours),
                    color: link.overtimeSeconds < 0 ? .red : .green,
                    icon: "clock.arrow.circlepath"
                )
                summaryRow(
                    title: "watch.summary.week".loc,
                    value: WatchFormat.hours(link.weeklyHours, decimal: link.useDecimalHours),
                    color: .blue,
                    icon: "briefcase.fill"
                )
                summaryRow(
                    title: "watch.summary.vacation".loc,
                    value: WatchFormat.days(link.vacationBalance),
                    color: .orange,
                    icon: "sun.max.fill"
                )
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("watch.tab.summary".loc)
    }

    private func summaryRow(title: String, value: String, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            Spacer()
        }
        .padding(8)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    WatchSummaryView().environment(WatchLink.shared)
}
