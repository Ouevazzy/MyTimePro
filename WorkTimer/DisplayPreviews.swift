#if DEBUG
import SwiftData
import Foundation
import SwiftUI

/// Historique en mémoire, utilisé uniquement par les aperçus de présentation.
@MainActor
enum DisplayPreviewData {
    static func makeContainer(negativeBalance: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: WorkDay.self, configurations: configuration)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for offset in 0..<45 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let targetHours = UserSettings.shared.expectedDailyHours(for: date, calendar: calendar)
            guard targetHours > 0 else { continue }

            let type: WorkDayType = offset % 17 == 0 ? .vacation : offset % 23 == 0 ? .sickLeave : .work
            if type == .work {
                let hours = max(0.5, targetHours + (negativeBalance ? -0.5 : 0.5))
                let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date)!
                let end = start.addingTimeInterval((hours + 1) * 3600)
                container.mainContext.insert(WorkDay(
                    date: date, startTime: start, endTime: end,
                    breakDuration: 3600, totalHours: hours,
                    overtimeSeconds: Int(round((hours - targetHours) * 3600)),
                    bonusAmount: offset % 11 == 0 ? 25 : 0
                ))
            } else {
                container.mainContext.insert(WorkDay(date: date, breakDuration: 0, type: type))
            }
        }

        try container.mainContext.save()
        return container
    }

    static var calendarSelectionDate: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date()))!
    }

    static func makeCalendarContainer() throws -> ModelContainer {
        let container = try makeContainer()
        let calendar = Calendar.current
        let date = calendarSelectionDate
        let existing = try container.mainContext.fetch(FetchDescriptor<WorkDay>()).filter {
            calendar.isDate($0.date, inSameDayAs: date)
        }
        existing.forEach { container.mainContext.delete($0) }

        for (startHour, endHour) in [(8, 12), (13, 17)] {
            container.mainContext.insert(WorkDay(
                date: date,
                startTime: calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: date),
                endTime: calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: date),
                breakDuration: 0, totalHours: 4
            ))
        }
        container.mainContext.insert(WorkDay(date: date, breakDuration: 0, type: .halfDayVacation))
        let entries = try container.mainContext.fetch(FetchDescriptor<WorkDay>())
        WorkDay.reconcileDailyOvertime(for: entries)
        try container.mainContext.save()
        return container
    }
}

#Preview("Calendrier — plusieurs entrées") {
    NavigationStack {
        CalendarView(focusedDate: .constant(DisplayPreviewData.calendarSelectionDate))
            .modelContainer(try! DisplayPreviewData.makeCalendarContainer())
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }
}
#endif
