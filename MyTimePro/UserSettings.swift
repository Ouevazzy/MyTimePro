import Foundation
import SwiftUI

@Observable
class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    @AppStorage("lastStartTime") private var lastStartTimeString: String = ""
    var lastStartTime: Date? {
        get {
            guard !lastStartTimeString.isEmpty,
                  let date = DateFormatter.timeOnly.date(from: lastStartTimeString) else { return nil }
            return Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: date),
                                       minute: Calendar.current.component(.minute, from: date),
                                       second: 0,
                                       of: Date()) ?? nil
        }
        set {
            if let date = newValue {
                lastStartTimeString = DateFormatter.timeOnly.string(from: date)
            } else {
                lastStartTimeString = ""
            }
        }
    }
    
    @AppStorage("lastEndTime") private var lastEndTimeString: String = ""
    var lastEndTime: Date? {
        get {
            guard !lastEndTimeString.isEmpty,
                  let date = DateFormatter.timeOnly.date(from: lastEndTimeString) else { return nil }
            return Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: date),
                                       minute: Calendar.current.component(.minute, from: date),
                                       second: 0,
                                       of: Date()) ?? nil
        }
        set {
            if let date = newValue {
                lastEndTimeString = DateFormatter.timeOnly.string(from: date)
            } else {
                lastEndTimeString = ""
            }
        }
    }
    
    @AppStorage("standardDailyHours") var standardDailyHours: Double = 7.4
    @AppStorage("useDecimalHours") var useDecimalHours: Bool = false
    
    @AppStorage("mondayEnabled") var mondayEnabled: Bool = true
    @AppStorage("tuesdayEnabled") var tuesdayEnabled: Bool = true
    @AppStorage("wednesdayEnabled") var wednesdayEnabled: Bool = true
    @AppStorage("thursdayEnabled") var thursdayEnabled: Bool = true
    @AppStorage("fridayEnabled") var fridayEnabled: Bool = true
    @AppStorage("saturdayEnabled") var saturdayEnabled: Bool = false
    @AppStorage("sundayEnabled") var sundayEnabled: Bool = false
    
    var workingDays: [Bool] {
        [mondayEnabled, tuesdayEnabled, wednesdayEnabled, thursdayEnabled, fridayEnabled, saturdayEnabled, sundayEnabled]
    }
    
    private init() {}
}

extension DateFormatter {
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
