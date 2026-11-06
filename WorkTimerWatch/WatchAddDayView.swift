//
//  WatchAddDayView.swift
//  WorkTimerWatch
//
//  Saisie rapide d'une journée depuis la montre (envoyée à l'iPhone).
//

import SwiftUI

struct WatchAddDayView: View {
    @Environment(WatchLink.self) private var link

    @State private var date = Date()
    @State private var startTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var breakMinutes = 60
    @State private var type: WatchDayType = .work
    @State private var bonus = 0
    @State private var justSaved = false

    private var isValid: Bool {
        guard type.isWork else { return true }
        return endTime > startTime
    }

    var body: some View {
        Form {
            Picker("Type", selection: $type) {
                ForEach(WatchDayType.allCases) { t in
                    Label(t.label, systemImage: t.icon).tag(t)
                }
            }

            DatePicker("Date", selection: $date, displayedComponents: .date)

            if type.isWork {
                DatePicker("Début", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("Fin", selection: $endTime, displayedComponents: .hourAndMinute)
                Stepper(value: $breakMinutes, in: 0...480, step: 15) {
                    Text("Pause \(breakMinutes) min")
                }
                Stepper(value: $bonus, in: 0...500, step: 5) {
                    Text("Bonus \(bonus)")
                }
                if !isValid {
                    Text("La fin doit être après le début")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Button {
                save()
            } label: {
                Label(justSaved ? "Enregistré ✓" : "Enregistrer",
                      systemImage: justSaved ? "checkmark.circle.fill" : "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(justSaved ? .green : .blue)
            .disabled(!isValid)
        }
        .navigationTitle("Ajouter")
    }

    private func save() {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let start = combine(day: day, time: startTime, calendar: calendar)
        let end = combine(day: day, time: endTime, calendar: calendar)

        link.createDay(
            date: day,
            type: type.rawValue,
            start: start,
            end: end,
            breakSeconds: TimeInterval(breakMinutes * 60),
            bonus: Double(bonus)
        )

        withAnimation { justSaved = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { justSaved = false }
        }
    }

    private func combine(day: Date, time: Date, calendar: Calendar) -> Date {
        let c = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: c.hour ?? 0, minute: c.minute ?? 0, second: 0, of: day) ?? day
    }
}

#Preview {
    WatchAddDayView().environment(WatchLink.shared)
}
