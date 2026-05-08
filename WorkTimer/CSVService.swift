//
//  CSVService.swift
//  WorkTimer
//
//  Service d'export des données au format CSV
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

class CSVService {
    
    // MARK: - Singleton
    static let shared = CSVService()
    private init() {}
    
    // MARK: - Export Types
    enum ExportType: String, CaseIterable {
        case allData = "Toutes les données"
        case yearlyReport = "Rapport annuel"
        case monthlyReport = "Rapport mensuel"
        case vacationReport = "Rapport congés"
        case overtimeReport = "Rapport heures sup."
    }
    
    // MARK: - CSV Generation
    
    /// Génère un fichier CSV avec toutes les journées de travail
    func generateFullExport(workDays: [WorkDay]) -> String {
        var csv = "Date;Type;Début;Fin;Pause (min);Heures totales;Heures sup. (s);Bonus;Note\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let sortedDays = workDays
            .sorted { $0.date < $1.date }
        
        for day in sortedDays {
            let date = dateFormatter.string(from: day.date)
            let type = day.type.csvName
            let start = day.startTime.map { timeFormatter.string(from: $0) } ?? ""
            let end = day.endTime.map { timeFormatter.string(from: $0) } ?? ""
            let breakMin = Int(day.breakDuration / 60)
            let hours = String(format: "%.2f", day.totalHours)
            let overtime = day.overtimeSeconds
            let bonus = String(format: "%.2f", day.bonusAmount)
            let note = day.note?.replacingOccurrences(of: ";", with: ",") ?? ""
            
            csv += "\(date);\(type);\(start);\(end);\(breakMin);\(hours);\(overtime);\(bonus);\(note)\n"
        }
        
        return csv
    }
    
    /// Génère un rapport annuel
    func generateYearlyReport(workDays: [WorkDay], year: Int) -> String {
        let calendar = Calendar.current
        let settings = UserSettings.shared
        
        let yearDays = workDays.filter {
            calendar.component(.year, from: $0.date) == year
        }
        
        var csv = "Rapport annuel \(year)\n\n"
        csv += "Mois;Jours travaillés;Heures totales;Heures sup.;Congés;Maladie;Fériés\n"
        
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "fr_FR")
        monthFormatter.dateFormat = "MMMM"
        
        var yearTotalHours = 0.0
        var yearTotalOvertime = 0
        var yearWorkDays = 0
        var yearVacation = 0
        var yearSick = 0
        var yearHoliday = 0
        
        for month in 1...12 {
            let monthDays = yearDays.filter {
                calendar.component(.month, from: $0.date) == month
            }

            let workDaysCount = monthDays.filter { $0.type == .work }.count
            let totalHours = monthDays.filter { $0.type == .work }.reduce(0.0) { $0 + $1.totalHours }
            let overtime = monthDays.reduce(0) { $0 + $1.overtimeSeconds }
            let vacation = monthDays.filter { $0.type == .vacation || $0.type == .halfDayVacation }.count
            let sick = monthDays.filter { $0.type == .sickLeave }.count
            let holiday = monthDays.filter { $0.type == .holiday }.count

            var components = DateComponents()
            components.month = month
            guard let monthDate = calendar.date(from: components) else { continue }
            let monthName = monthFormatter.string(from: monthDate).capitalized
            
            let overtimeFormatted = formatOvertime(overtime)
            
            csv += "\(monthName);\(workDaysCount);\(String(format: "%.2f", totalHours));\(overtimeFormatted);\(vacation);\(sick);\(holiday)\n"
            
            yearTotalHours += totalHours
            yearTotalOvertime += overtime
            yearWorkDays += workDaysCount
            yearVacation += vacation
            yearSick += sick
            yearHoliday += holiday
        }
        
        csv += "\n"
        csv += "TOTAL;\(yearWorkDays);\(String(format: "%.2f", yearTotalHours));\(formatOvertime(yearTotalOvertime));\(yearVacation);\(yearSick);\(yearHoliday)\n"
        
        // Statistiques supplémentaires
        csv += "\n\nStatistiques\n"
        csv += "Moyenne heures/jour;\(String(format: "%.2f", yearWorkDays > 0 ? yearTotalHours / Double(yearWorkDays) : 0))\n"
        csv += "Heures standard/semaine;\(settings.weeklyHours)\n"
        csv += "Jours de congés annuels;\(settings.annualVacationDays)\n"
        
        return csv
    }
    
    /// Génère un rapport mensuel
    func generateMonthlyReport(workDays: [WorkDay], year: Int, month: Int) -> String {
        let calendar = Calendar.current
        
        let monthDays = workDays.filter {
            calendar.component(.year, from: $0.date) == year &&
            calendar.component(.month, from: $0.date) == month
        }.sorted { $0.date < $1.date }
        
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "fr_FR")
        monthFormatter.dateFormat = "MMMM yyyy"

        var components = DateComponents()
        components.year = year
        components.month = month
        guard let monthDate = calendar.date(from: components) else { return "" }
        let monthName = monthFormatter.string(from: monthDate).capitalized
        
        var csv = "Rapport mensuel - \(monthName)\n\n"
        csv += "Date;Jour;Type;Début;Fin;Pause;Heures;Heures sup.\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM"
        
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "fr_FR")
        dayFormatter.dateFormat = "EEEE"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        var totalHours = 0.0
        var totalOvertime = 0
        
        for day in monthDays {
            let date = dateFormatter.string(from: day.date)
            let dayName = dayFormatter.string(from: day.date).capitalized
            let type = day.type.csvName
            let start = day.startTime.map { timeFormatter.string(from: $0) } ?? "-"
            let end = day.endTime.map { timeFormatter.string(from: $0) } ?? "-"
            let breakMin = day.type == .work ? "\(Int(day.breakDuration / 60))min" : "-"
            let hours = day.type == .work ? String(format: "%.2f", day.totalHours) : "-"
            let overtime = day.type == .work ? formatOvertime(day.overtimeSeconds) : "-"
            
            csv += "\(date);\(dayName);\(type);\(start);\(end);\(breakMin);\(hours);\(overtime)\n"
            
            if day.type == .work {
                totalHours += day.totalHours
            }
            totalOvertime += day.overtimeSeconds
        }
        
        csv += "\n"
        csv += "TOTAL;;;;\(String(format: "%.2f", totalHours));\(formatOvertime(totalOvertime))\n"
        
        return csv
    }
    
    /// Génère un rapport des congés
    func generateVacationReport(workDays: [WorkDay], settings: UserSettings) -> String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let startYear = calendar.component(.year, from: settings.vacationStartDate)
        
        var csv = "Rapport des congés\n\n"
        csv += "Année;Report entrant;Droits acquis;Utilisés;Solde\n"
        
        var carryIn = settings.initialVacationDays
        
        for year in startYear...currentYear {
            let yearVacations = workDays.filter {
                calendar.component(.year, from: $0.date) == year &&
                ($0.type == .vacation || $0.type == .halfDayVacation)
            }
            
            var used = 0.0
            for day in yearVacations {
                used += day.type == .vacation ? 1.0 : 0.5
            }
            
            let entitlement = year == startYear ? 0.0 : Double(settings.annualVacationDays)
            let balance = max(0, carryIn + entitlement - used)
            
            csv += "\(year);\(String(format: "%.1f", carryIn));\(String(format: "%.1f", entitlement));\(String(format: "%.1f", used));\(String(format: "%.1f", balance))\n"
            
            carryIn = balance
        }
        
        csv += "\n"
        csv += "Solde actuel;\(String(format: "%.1f", carryIn)) jours\n"
        
        // Liste détaillée des congés
        csv += "\n\nDétail des congés\n"
        csv += "Date;Type;Année\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        let allVacations = workDays.filter {
            $0.type == .vacation || $0.type == .halfDayVacation
        }.sorted { $0.date < $1.date }
        
        for day in allVacations {
            let date = dateFormatter.string(from: day.date)
            let type = day.type == .vacation ? "Journée complète" : "Demi-journée"
            let year = calendar.component(.year, from: day.date)
            csv += "\(date);\(type);\(year)\n"
        }
        
        return csv
    }
    
    /// Génère un rapport des heures supplémentaires
    func generateOvertimeReport(workDays: [WorkDay]) -> String {
        let calendar = Calendar.current
        
        let workOnlyDays = workDays.filter {
            $0.type == .work
        }.sorted { $0.date < $1.date }
        
        var csv = "Rapport des heures supplémentaires\n\n"
        csv += "Date;Heures travaillées;Heures sup.;Cumul\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        var cumulative = 0
        
        for day in workOnlyDays {
            let date = dateFormatter.string(from: day.date)
            let hours = String(format: "%.2f", day.totalHours)
            let overtime = day.overtimeSeconds
            cumulative += overtime
            
            csv += "\(date);\(hours);\(formatOvertime(overtime));\(formatOvertime(cumulative))\n"
        }
        
        csv += "\n"
        csv += "Total heures supplémentaires;\(formatOvertime(cumulative))\n"
        
        // Résumé par année
        csv += "\n\nRésumé par année\n"
        csv += "Année;Heures sup.\n"
        
        let years = Set(workOnlyDays.map { calendar.component(.year, from: $0.date) }).sorted()
        
        for year in years {
            let yearOvertime = workOnlyDays
                .filter { calendar.component(.year, from: $0.date) == year }
                .reduce(0) { $0 + $1.overtimeSeconds }
            csv += "\(year);\(formatOvertime(yearOvertime))\n"
        }
        
        return csv
    }
    
    // MARK: - File Creation
    
    func createCSVFile(content: String, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename).csv")
        
        // Ajouter BOM UTF-8 pour Excel
        let bom = "\u{FEFF}"
        let contentWithBom = bom + content
        
        do {
            try contentWithBom.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            AppLogger.error("Failed to create CSV file", category: AppLogger.general, error: error)
            return nil
        }
    }
    
    // MARK: - Helpers
    
    private func formatOvertime(_ seconds: Int) -> String {
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        let sign = seconds >= 0 ? "+" : "-"
        return "\(sign)\(hours)h\(String(format: "%02d", minutes))"
    }
}

// MARK: - WorkDayType CSV Extension

extension WorkDayType {
    var csvName: String {
        switch self {
        case .work: return "Travail"
        case .vacation: return "Congé"
        case .halfDayVacation: return "Demi-congé"
        case .sickLeave: return "Maladie"
        case .holiday: return "Férié"
        case .compensatory: return "Récupération"
        case .training: return "Formation"
        }
    }
}

// MARK: - CSV Export View

struct CSVExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let workDays: [WorkDay]
    
    @State private var selectedType: CSVService.ExportType = .allData
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var isExporting = false
    
    private let csvService = CSVService.shared
    private let settings = UserSettings.shared
    
    private var availableYears: [Int] {
        let years = Set(workDays.map { Calendar.current.component(.year, from: $0.date) })
        return years.sorted(by: >)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type d'export", selection: $selectedType) {
                        ForEach(CSVService.ExportType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                } header: {
                    Text("Type de rapport")
                }
                
                if selectedType == .yearlyReport || selectedType == .monthlyReport {
                    Section {
                        Picker("Année", selection: $selectedYear) {
                            ForEach(availableYears, id: \.self) { year in
                                Text(String(year)).tag(year)
                            }
                        }
                        
                        if selectedType == .monthlyReport {
                            Picker("Mois", selection: $selectedMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(monthName(month)).tag(month)
                                }
                            }
                        }
                    } header: {
                        Text("Période")
                    }
                }
                
                Section {
                    Button {
                        exportCSV()
                    } label: {
                        HStack {
                            Spacer()
                            if isExporting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Label("Exporter en CSV", systemImage: "square.and.arrow.up")
                            Spacer()
                        }
                    }
                    .disabled(isExporting)
                } footer: {
                    Text("Le fichier CSV peut être ouvert avec Excel, Numbers ou Google Sheets.")
                }
            }
            .navigationTitle("Export CSV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private func exportCSV() {
        isExporting = true
        Haptic.impact(.medium)
        
        DispatchQueue.global(qos: .userInitiated).async {
            let content: String
            let filename: String
            
            switch selectedType {
            case .allData:
                content = csvService.generateFullExport(workDays: workDays)
                filename = "WorkTimer_Export_Complet"
                
            case .yearlyReport:
                content = csvService.generateYearlyReport(workDays: workDays, year: selectedYear)
                filename = "WorkTimer_Rapport_\(selectedYear)"
                
            case .monthlyReport:
                content = csvService.generateMonthlyReport(workDays: workDays, year: selectedYear, month: selectedMonth)
                filename = "WorkTimer_Rapport_\(selectedYear)_\(String(format: "%02d", selectedMonth))"
                
            case .vacationReport:
                content = csvService.generateVacationReport(workDays: workDays, settings: settings)
                filename = "WorkTimer_Conges"
                
            case .overtimeReport:
                content = csvService.generateOvertimeReport(workDays: workDays)
                filename = "WorkTimer_Heures_Sup"
            }
            
            let url = csvService.createCSVFile(content: content, filename: filename)
            
            DispatchQueue.main.async {
                isExporting = false
                if let url = url {
                    exportURL = url
                    showingShareSheet = true
                    Haptic.notification(.success)
                } else {
                    Haptic.notification(.error)
                }
            }
        }
    }
    
    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM"
        var components = DateComponents()
        components.month = month
        guard let date = Calendar.current.date(from: components) else { return "" }
        return formatter.string(from: date).capitalized
    }
}

#Preview {
    CSVExportView(workDays: [])
}

