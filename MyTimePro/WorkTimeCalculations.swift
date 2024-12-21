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
}
