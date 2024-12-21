import Foundation
import SwiftUI

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    @Published @AppStorage("lastStartTime") private var lastStartTimeString: String = ""
    var lastStartTime: Date? {
        get {
            guard !lastStartTimeString.isEmpty,
                  let date = timeOnlyFormatter.date(from: lastStartTimeString) else { return nil }
            return Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: date),
                                       minute: Calendar.current.component(.minute, from: date),
                                       second: 0,
                                       of: Date()) ?? nil
        }
        set {
            if let date = newValue {
                lastStartTimeString = timeOnlyFormatter.string(from: date)
            } else {
                lastStartTimeString = ""
            }
        }
    }
    
    @Published @AppStorage("lastEndTime") private var lastEndTimeString: String = ""
    var lastEndTime: Date? {
        get {
            guard !lastEndTimeString.isEmpty,
                  let date = timeOnlyFormatter.date(from: lastEndTimeString) else { return nil }
            return Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: date),
                                       minute: Calendar.current.component(.minute, from: date),
                                       second: 0,
                                       of: Date()) ?? nil
        }
        set {
            if let date = newValue {
                lastEndTimeString = timeOnlyFormatter.string(from: date)
            } else {
                lastEndTimeString = ""
            }
        }
    }
    
    @Published @AppStorage("standardDailyHours") var standardDailyHours: Double = 7.4
    @Published @AppStorage("useDecimalHours") var useDecimalHours: Bool = false
    
    @Published @AppStorage("mondayEnabled") var mondayEnabled: Bool = true
    @Published @AppStorage("tuesdayEnabled") var tuesdayEnabled: Bool = true
    @Published @AppStorage("wednesdayEnabled") var wednesdayEnabled: Bool = true
    @Published @AppStorage("thursdayEnabled") var thursdayEnabled: Bool = true
    @Published @AppStorage("fridayEnabled") var fridayEnabled: Bool = true
    @Published @AppStorage("saturdayEnabled") var saturdayEnabled: Bool = false
    @Published @AppStorage("sundayEnabled") var sundayEnabled: Bool = false
    
    var workingDays: [Bool] {
        [mondayEnabled, tuesdayEnabled, wednesdayEnabled, thursdayEnabled, fridayEnabled, saturdayEnabled, sundayEnabled]
    }
    
    private let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    private init() {}
}
