import Foundation
import SwiftUI

@MainActor
class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    @Published var workDayDuration: TimeInterval = 7 * 3600 + 1800 // 7h30 par défaut
    @Published var pauseDuration: TimeInterval = 3600 // 1h par défaut
    @Published var workDaysPerWeek: Int = 5
    @Published var selectedExportType: ExportType = .pdf
    
    // Clés pour UserDefaults
    private let workDayDurationKey = "workDayDuration"
    private let pauseDurationKey = "pauseDuration"
    private let workDaysPerWeekKey = "workDaysPerWeek"
    private let selectedExportTypeKey = "selectedExportType"
    
    init() {
        // Chargement des valeurs depuis UserDefaults
        if let workDayDuration = UserDefaults.standard.object(forKey: workDayDurationKey) as? TimeInterval {
            self.workDayDuration = workDayDuration
        }
        
        if let pauseDuration = UserDefaults.standard.object(forKey: pauseDurationKey) as? TimeInterval {
            self.pauseDuration = pauseDuration
        }
        
        if let workDaysPerWeek = UserDefaults.standard.object(forKey: workDaysPerWeekKey) as? Int {
            self.workDaysPerWeek = workDaysPerWeek
        }
        
        if let exportTypeRaw = UserDefaults.standard.string(forKey: selectedExportTypeKey),
           let exportType = ExportType(rawValue: exportTypeRaw) {
            self.selectedExportType = exportType
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(workDayDuration, forKey: workDayDurationKey)
        UserDefaults.standard.set(pauseDuration, forKey: pauseDurationKey)
        UserDefaults.standard.set(workDaysPerWeek, forKey: workDaysPerWeekKey)
        UserDefaults.standard.set(selectedExportType.rawValue, forKey: selectedExportTypeKey)
    }
}
