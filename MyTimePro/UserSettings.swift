import Foundation
import SwiftUI

class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    let userDefaults = UserDefaults.standard
    
    @Published var lastStartTimeString: String
    @Published var lastEndTimeString: String
    @Published var standardDailyHours: Double
    @Published var useDecimalHours: Bool
    @Published var mondayEnabled: Bool
    @Published var tuesdayEnabled: Bool
    @Published var wednesdayEnabled: Bool
    @Published var thursdayEnabled: Bool
    @Published var fridayEnabled: Bool
    @Published var saturdayEnabled: Bool
    @Published var sundayEnabled: Bool
    @Published var annualVacationDays: Double
    
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
                userDefaults.set(lastStartTimeString, forKey: "lastStartTime")
            } else {
                lastStartTimeString = ""
                userDefaults.removeObject(forKey: "lastStartTime")
            }
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
                userDefaults.set(lastEndTimeString, forKey: "lastEndTime")
            } else {
                lastEndTimeString = ""
                userDefaults.removeObject(forKey: "lastEndTime")
            }
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
        // Initialisation des propriétés
        self.lastStartTimeString = ""
        self.lastEndTimeString = ""
        self.standardDailyHours = 7.4
        self.useDecimalHours = false
        self.mondayEnabled = true
        self.tuesdayEnabled = true
        self.wednesdayEnabled = true
        self.thursdayEnabled = true
        self.fridayEnabled = true
        self.saturdayEnabled = false
        self.sundayEnabled = false
        self.annualVacationDays = 25.0  // Valeur par défaut de 25 jours de congés annuels
        
        // Chargement des valeurs depuis UserDefaults
        if let startTime = userDefaults.string(forKey: "lastStartTime") {
            self.lastStartTimeString = startTime
        }
        
        if let endTime = userDefaults.string(forKey: "lastEndTime") {
            self.lastEndTimeString = endTime
        }
        
        if userDefaults.object(forKey: "standardDailyHours") != nil {
            self.standardDailyHours = userDefaults.double(forKey: "standardDailyHours")
        }
        
        if userDefaults.object(forKey: "useDecimalHours") != nil {
            self.useDecimalHours = userDefaults.bool(forKey: "useDecimalHours")
        }
        
        if userDefaults.object(forKey: "mondayEnabled") != nil {
            self.mondayEnabled = userDefaults.bool(forKey: "mondayEnabled")
        }
        
        if userDefaults.object(forKey: "tuesdayEnabled") != nil {
            self.tuesdayEnabled = userDefaults.bool(forKey: "tuesdayEnabled")
        }
        
        if userDefaults.object(forKey: "wednesdayEnabled") != nil {
            self.wednesdayEnabled = userDefaults.bool(forKey: "wednesdayEnabled")
        }
        
        if userDefaults.object(forKey: "thursdayEnabled") != nil {
            self.thursdayEnabled = userDefaults.bool(forKey: "thursdayEnabled")
        }
        
        if userDefaults.object(forKey: "fridayEnabled") != nil {
            self.fridayEnabled = userDefaults.bool(forKey: "fridayEnabled")
        }
        
        if userDefaults.object(forKey: "saturdayEnabled") != nil {
            self.saturdayEnabled = userDefaults.bool(forKey: "saturdayEnabled")
        }
        
        if userDefaults.object(forKey: "sundayEnabled") != nil {
            self.sundayEnabled = userDefaults.bool(forKey: "sundayEnabled")
        }
        
        if userDefaults.object(forKey: "annualVacationDays") != nil {
            self.annualVacationDays = userDefaults.double(forKey: "annualVacationDays")
        }
        
        // Configuration des observers pour sauvegarder les changements
        setupObservers()
    }
    
    private func setupObservers() {
        self.objectWillChange.sink { [weak self] _ in
            guard let self = self else { return }
            
            userDefaults.set(self.lastStartTimeString, forKey: "lastStartTime")
            userDefaults.set(self.lastEndTimeString, forKey: "lastEndTime")
            userDefaults.set(self.standardDailyHours, forKey: "standardDailyHours")
            userDefaults.set(self.useDecimalHours, forKey: "useDecimalHours")
            userDefaults.set(self.mondayEnabled, forKey: "mondayEnabled")
            userDefaults.set(self.tuesdayEnabled, forKey: "tuesdayEnabled")
            userDefaults.set(self.wednesdayEnabled, forKey: "wednesdayEnabled")
            userDefaults.set(self.thursdayEnabled, forKey: "thursdayEnabled")
            userDefaults.set(self.fridayEnabled, forKey: "fridayEnabled")
            userDefaults.set(self.saturdayEnabled, forKey: "saturdayEnabled")
            userDefaults.set(self.sundayEnabled, forKey: "sundayEnabled")
            userDefaults.set(self.annualVacationDays, forKey: "annualVacationDays")
        }
    }
}
