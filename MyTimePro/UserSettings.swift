import Foundation
import SwiftUI

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    let userDefaults = UserDefaults.standard
    
    @Published var lastStartTimeString: String {
        didSet {
            userDefaults.set(lastStartTimeString, forKey: "lastStartTime")
        }
    }
    
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
    
    @Published var lastEndTimeString: String {
        didSet {
            userDefaults.set(lastEndTimeString, forKey: "lastEndTime")
        }
    }
    
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
    
    @Published var standardDailyHours: Double {
        didSet {
            userDefaults.set(standardDailyHours, forKey: "standardDailyHours")
        }
    }
    
    @Published var useDecimalHours: Bool {
        didSet {
            userDefaults.set(useDecimalHours, forKey: "useDecimalHours")
        }
    }
    
    @Published var mondayEnabled: Bool {
        didSet {
            userDefaults.set(mondayEnabled, forKey: "mondayEnabled")
        }
    }
    
    @Published var tuesdayEnabled: Bool {
        didSet {
            userDefaults.set(tuesdayEnabled, forKey: "tuesdayEnabled")
        }
    }
    
    @Published var wednesdayEnabled: Bool {
        didSet {
            userDefaults.set(wednesdayEnabled, forKey: "wednesdayEnabled")
        }
    }
    
    @Published var thursdayEnabled: Bool {
        didSet {
            userDefaults.set(thursdayEnabled, forKey: "thursdayEnabled")
        }
    }
    
    @Published var fridayEnabled: Bool {
        didSet {
            userDefaults.set(fridayEnabled, forKey: "fridayEnabled")
        }
    }
    
    @Published var saturdayEnabled: Bool {
        didSet {
            userDefaults.set(saturdayEnabled, forKey: "saturdayEnabled")
        }
    }
    
    @Published var sundayEnabled: Bool {
        didSet {
            userDefaults.set(sundayEnabled, forKey: "sundayEnabled")
        }
    }
    
    var workingDays: [Bool] {
        [mondayEnabled, tuesdayEnabled, wednesdayEnabled, thursdayEnabled, fridayEnabled, saturdayEnabled, sundayEnabled]
    }
    
    private let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    private init() {
        // Initialisation des valeurs depuis UserDefaults
        self.lastStartTimeString = userDefaults.string(forKey: "lastStartTime") ?? ""
        self.lastEndTimeString = userDefaults.string(forKey: "lastEndTime") ?? ""
        self.standardDailyHours = userDefaults.double(forKey: "standardDailyHours")
        if self.standardDailyHours == 0 { self.standardDailyHours = 7.4 }
        
        self.useDecimalHours = userDefaults.bool(forKey: "useDecimalHours")
        
        self.mondayEnabled = userDefaults.bool(forKey: "mondayEnabled")
        if !userDefaults.contains(key: "mondayEnabled") { self.mondayEnabled = true }
        
        self.tuesdayEnabled = userDefaults.bool(forKey: "tuesdayEnabled")
        if !userDefaults.contains(key: "tuesdayEnabled") { self.tuesdayEnabled = true }
        
        self.wednesdayEnabled = userDefaults.bool(forKey: "wednesdayEnabled")
        if !userDefaults.contains(key: "wednesdayEnabled") { self.wednesdayEnabled = true }
        
        self.thursdayEnabled = userDefaults.bool(forKey: "thursdayEnabled")
        if !userDefaults.contains(key: "thursdayEnabled") { self.thursdayEnabled = true }
        
        self.fridayEnabled = userDefaults.bool(forKey: "fridayEnabled")
        if !userDefaults.contains(key: "fridayEnabled") { self.fridayEnabled = true }
        
        self.saturdayEnabled = userDefaults.bool(forKey: "saturdayEnabled")
        self.sundayEnabled = userDefaults.bool(forKey: "sundayEnabled")
    }
}

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}
