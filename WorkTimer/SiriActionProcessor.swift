import Foundation
import SwiftData

@MainActor
struct SiriActionProcessor {
    let modelContext: ModelContext
    var calendar: Calendar = .current

    func process(_ action: SiriShortcutsHelper.SiriAction) throws {
        let affectedDate: Date
        switch action {
        case .createEntry(let arrivalTime):
            try applyArrival(at: arrivalTime)
            affectedDate = calendar.startOfDay(for: arrivalTime)
        case .updateEntry(let departureTime):
            try applyDeparture(at: departureTime)
            affectedDate = calendar.startOfDay(for: departureTime)
        case .quickAdd(let type):
            try quickAddWorkDay(type: type)
            affectedDate = calendar.startOfDay(for: Date())
        case .openDestination, .openCalendarDate, .startTimer, .stopTimer:
            // Gérés directement par la vue (chronomètre / navigation).
            return
        }

        _ = try WorkDay.reconcileDailyOvertime(
            in: modelContext,
            for: [affectedDate],
            calendar: calendar
        )
        try modelContext.save()
        SiriSummaryCacheService(calendar: calendar).refresh(using: modelContext)
    }

    private func applyArrival(at arrivalTime: Date) throws {
        let date = calendar.startOfDay(for: arrivalTime)
        let (workDay, isNew) = try workDayForSiriAction(on: date)
        let previousDate = workDay.date
        let previousType = workDay.type

        if isNew {
            modelContext.insert(workDay)
        }

        workDay.date = date
        workDay.type = .work
        workDay.startTime = arrivalTime

        if let endTime = workDay.endTime, endTime > arrivalTime {
            workDay.updateData(
                startTime: arrivalTime,
                endTime: endTime,
                breakDuration: min(workDay.breakDuration, endTime.timeIntervalSince(arrivalTime))
            )
        } else {
            workDay.endTime = nil
            workDay.breakDuration = UserSettings.shared.lastBreakDuration
            workDay.totalHours = 0
            workDay.overtimeSeconds = 0
            markModified(workDay)
        }

        StatsCache.shared.onWorkDayChanged(workDay, previousDate: previousDate, previousType: previousType)
    }

    private func applyDeparture(at departureTime: Date) throws {
        let date = calendar.startOfDay(for: departureTime)
        let (workDay, isNew) = try workDayForSiriAction(on: date)
        let previousDate = workDay.date
        let previousType = workDay.type
        let startTime: Date

        if let existingStartTime = workDay.startTime, existingStartTime < departureTime {
            startTime = existingStartTime
        } else {
            startTime = defaultStartTime(on: date, before: departureTime)
        }

        let breakDuration = min(
            UserSettings.shared.lastBreakDuration,
            max(0, departureTime.timeIntervalSince(startTime))
        )

        if isNew {
            modelContext.insert(workDay)
        }

        workDay.date = date
        workDay.type = .work
        workDay.updateData(startTime: startTime, endTime: departureTime, breakDuration: breakDuration)
        StatsCache.shared.onWorkDayChanged(workDay, previousDate: previousDate, previousType: previousType)
    }

    private func quickAddWorkDay(type: WorkDayType) throws {
        let date = calendar.startOfDay(for: Date())
        let (workDay, isNew) = try workDayForSiriAction(on: date)
        let previousDate = workDay.date
        let previousType = workDay.type

        if isNew {
            modelContext.insert(workDay)
        }

        workDay.date = date
        workDay.type = type

        if type.isWorkDay {
            let startTime = workDay.startTime
                ?? alignedTime(UserSettings.shared.lastStartTime, on: date)
                ?? defaultStartTime(on: date)
            let endTime = workDay.endTime
                ?? alignedTime(UserSettings.shared.lastEndTime, on: date)
                ?? calendar.date(byAdding: .hour, value: 9, to: startTime)
                ?? startTime
            let validEndTime = endTime > startTime
                ? endTime
                : (calendar.date(byAdding: .hour, value: 9, to: startTime) ?? endTime)

            workDay.updateData(
                startTime: startTime,
                endTime: validEndTime,
                breakDuration: min(UserSettings.shared.lastBreakDuration, validEndTime.timeIntervalSince(startTime))
            )
        } else {
            workDay.updateData(startTime: nil, endTime: nil, breakDuration: 0)
        }

        StatsCache.shared.onWorkDayChanged(workDay, previousDate: previousDate, previousType: previousType)
    }

    private func workDayForSiriAction(on date: Date) throws -> (WorkDay, Bool) {
        if let existingWorkDay = try activeWorkDay(on: date) {
            return (existingWorkDay, false)
        }
        return (WorkDay(date: date, type: .work), true)
    }

    private func activeWorkDay(on date: Date) throws -> WorkDay? {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate<WorkDay> { workDay in
                workDay.date >= startOfDay && workDay.date < endOfDay && !workDay.isDeleted
            },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )

        return try modelContext.fetch(descriptor).first
    }

    private func defaultStartTime(on date: Date, before endTime: Date? = nil) -> Date {
        let preferredStart = alignedTime(UserSettings.shared.lastStartTime, on: date)
            ?? calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date)
            ?? date

        guard let endTime, preferredStart >= endTime else {
            return preferredStart
        }

        return calendar.date(byAdding: .hour, value: -8, to: endTime) ?? preferredStart
    }

    private func alignedTime(_ time: Date, on date: Date) -> Date? {
        let components = calendar.dateComponents([.hour, .minute, .second], from: time)
        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            of: date
        )
    }

    private func markModified(_ workDay: WorkDay) {
        workDay.modifiedAt = Date()
        workDay.needsSync = true
    }
}
