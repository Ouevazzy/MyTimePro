import Foundation
import SwiftData
import SwiftUI

@Model
final class WorkDay {
    #Index<WorkDay>([\.date], [\.typeRawValue])

    // MARK: - Properties
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var date: Date = Date()
    var startTime: Date?
    var endTime: Date?
    var breakDuration: TimeInterval = 3600
    var totalHours: Double = 0.0
    var overtimeSeconds: Int = 0
    var typeRawValue: String = WorkDayType.work.rawValue
    var note: String?
    var bonusAmount: Double = 0.0

    // MARK: - Computed Properties
    var type: WorkDayType {
        get { WorkDayType(rawValue: typeRawValue) ?? .work }
        set { typeRawValue = newValue.rawValue }
    }

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        startTime: Date? = nil,
        endTime: Date? = nil,
        breakDuration: TimeInterval = 3600,
        totalHours: Double = 0.0,
        overtimeSeconds: Int = 0,
        type: WorkDayType = .work,
        note: String? = nil,
        bonusAmount: Double = 0.0
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.breakDuration = breakDuration
        self.totalHours = totalHours
        self.overtimeSeconds = overtimeSeconds
        self.type = type
        self.note = note
        self.bonusAmount = bonusAmount
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    // MARK: - Public Methods
    func calculateHours() {
        let settings = UserSettings.shared
        let calendar = Calendar.current
        var standardSeconds = 0

        if type == .work || type == .compensatory {
            let weekday = calendar.component(.weekday, from: date)
            let adjustedWeekday = weekday == 1 ? 6 : weekday - 2
            if adjustedWeekday >= 0 && adjustedWeekday < settings.workingDays.count
                && settings.workingDays[adjustedWeekday] {
                standardSeconds = Int(round(settings.standardDailyHours * 3600))
            }
        }

        totalHours = 0
        overtimeSeconds = 0

        switch type {
        case .work:
            guard let start = startTime, let end = endTime else { return }
            let workedSeconds = max(0, end.timeIntervalSince(start) - breakDuration)
            totalHours = workedSeconds / 3600.0
            overtimeSeconds = Int(round(workedSeconds)) - standardSeconds
        case .vacation, .halfDayVacation, .sickLeave, .holiday:
            break
        case .compensatory:
            overtimeSeconds = -standardSeconds
        case .training:
            totalHours = Double(standardSeconds) / 3600.0
        }

        if !type.isWorkDay {
            startTime = nil
            endTime = nil
            breakDuration = 0
            bonusAmount = 0
        }

        modifiedAt = Date()
    }

    func updateData(startTime: Date?, endTime: Date?, breakDuration: TimeInterval) {
        if type.isWorkDay {
            self.startTime = startTime
            self.endTime = endTime
            if let s = startTime, let e = endTime, e >= s {
                let worked = max(0, e.timeIntervalSince(s))
                self.breakDuration = min(max(0, breakDuration), worked)
            } else {
                self.breakDuration = max(0, breakDuration)
            }
        }
        calculateHours()
    }

    // MARK: - Formatted Properties
    var formattedTotalHours: String {
        UserSettings.shared.useDecimalHours
            ? String(format: "%.2f", totalHours)
            : formatTimeInterval(totalHours * 3600)
    }

    var formattedOvertimeHours: String {
        UserSettings.shared.useDecimalHours
            ? String(format: "%.2f", Double(overtimeSeconds) / 3600.0)
            : formatTimeInterval(Double(overtimeSeconds))
    }

    // MARK: - Private Helpers
    private func formatTimeInterval(_ seconds: Double) -> String {
        let totalMinutes = Int(round(seconds / 60))
        let hours = abs(totalMinutes / 60)
        let minutes = abs(totalMinutes % 60)
        let sign = seconds < 0 ? "-" : ""
        return String(format: "%@%dh%02d", sign, hours, minutes)
    }
}

// MARK: - Validation
extension WorkDay {
    var isValid: Bool {
        if type.isWorkDay {
            guard let start = startTime, let end = endTime else { return false }
            guard end > start else { return false }
            guard breakDuration >= 0 else { return false }
            guard bonusAmount >= 0 else { return false }
            let duration = end.timeIntervalSince(start)
            guard duration <= 24 * 3600 else { return false }
            guard breakDuration <= duration else { return false }
        }
        let calendar = Calendar.current
        let maxFuture = calendar.date(byAdding: .year, value: 1,   to: Date()) ?? Date.distantFuture
        let minPast   = calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date.distantPast
        guard date >= minPast && date <= maxFuture else { return false }
        if let note = note, note.count > 500 { return false }
        return true
    }
}
