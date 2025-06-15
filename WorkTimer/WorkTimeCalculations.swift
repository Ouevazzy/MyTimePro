import Foundation

class WorkTimeCalculations {
    static func calculateTotalHours(startTime: Date, endTime: Date, breakDuration: TimeInterval) -> Double {
        let workedTime = endTime.timeIntervalSince(startTime) - breakDuration
        return workedTime / 3600.0 // Convertir les secondes en heures
    }

    static func calculateOvertimeHours(totalHours: Double, standardHours: Double) -> Double {
        return totalHours - standardHours
    }
    
    static func formattedTimeInterval(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(round(interval / 60))
        let hours = abs(totalMinutes / 60)
        let minutes = abs(totalMinutes % 60)
        let sign = interval < 0 ? "-" : ""
        return String(format: "%@%dh%02d", sign, hours, minutes)
    }

    static func workingDaysInMonth(year: Int, month: Int, workingWeekDays: [Bool]) -> Int {
        let calendar = Calendar.current
        // Ensure workingWeekDays has 7 elements, defaulting to false if not
        let safeWorkingWeekDays = workingWeekDays.count == 7 ? workingWeekDays : Array(repeating: false, count: 7)

        guard let monthStartDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: monthStartDate) else {
            return 0
        }

        var count = 0
        for dayOfMonth in range { // dayOfMonth is 1-based day number
            guard let date = calendar.date(bySetting: .day, value: dayOfMonth, of: monthStartDate) else { continue }
            let weekday = calendar.component(.weekday, from: date) // Sunday = 1, ..., Saturday = 7

            // Adjust weekday to match workingWeekDays array: Monday = 0, ..., Sunday = 6
            // Example: Sunday (1) becomes index 6. Monday (2) becomes index 0.
            let adjustedWeekday = (weekday - 2 + 7) % 7

            if adjustedWeekday >= 0 && adjustedWeekday < safeWorkingWeekDays.count && safeWorkingWeekDays[adjustedWeekday] {
                count += 1
            }
        }
        return count
    }

    static func expectedWorkingHours(forActualWorkDays actualWorkDays: Int, weeklyHours: Double, typicalWorkWeekDayCount: Int) -> Double {
        guard typicalWorkWeekDayCount > 0, weeklyHours > 0 else { return 0 }
        let dailyHours = weeklyHours / Double(typicalWorkWeekDayCount)
        return dailyHours * Double(actualWorkDays)
    }
}
