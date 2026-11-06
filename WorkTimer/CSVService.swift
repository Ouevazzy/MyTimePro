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
    private let delimiter = ";"
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

    func generateDetailedExport(workDays: [WorkDay], useDecimalHours: Bool) -> String {
        var rows: [[String]] = [
            "export.csv.header".localized
                .split(separator: ",")
                .map { String($0) }
        ]

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        for day in workDays.sorted(by: { $0.date < $1.date }) {
            let totalHours: String
            let overtimeHours: String
            if useDecimalHours {
                totalHours = decimal(day.totalHours)
                overtimeHours = decimal(Double(day.overtimeSeconds) / 3600.0)
            } else {
                totalHours = WorkTimeCalculations.formattedTimeInterval(day.totalHours * 3600)
                overtimeHours = WorkTimeCalculations.formattedTimeInterval(Double(day.overtimeSeconds))
            }

            rows.append([
                dateFormatter.string(from: day.date),
                day.type.localizedName,
                day.startTime.map { timeFormatter.string(from: $0) } ?? "",
                day.endTime.map { timeFormatter.string(from: $0) } ?? "",
                WorkTimeCalculations.formattedTimeInterval(day.breakDuration),
                totalHours,
                overtimeHours,
                decimal(day.bonusAmount),
                day.note ?? ""
            ])
        }

        return csv(rows)
    }

    /// Génère un fichier CSV avec toutes les journées de travail
    func generateFullExport(workDays: [WorkDay]) -> String {
        generateDetailedExport(workDays: workDays, useDecimalHours: UserSettings.shared.useDecimalHours)
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

            let workDaysCount = Set(
                monthDays
                    .filter { $0.type == .work }
                    .map { calendar.startOfDay(for: $0.date) }
            ).count
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

            csv += csvLine([
                monthName,
                String(workDaysCount),
                decimal(totalHours),
                overtimeFormatted,
                String(vacation),
                String(sick),
                String(holiday)
            ]) + "\n"
            
            yearTotalHours += totalHours
            yearTotalOvertime += overtime
            yearWorkDays += workDaysCount
            yearVacation += vacation
            yearSick += sick
            yearHoliday += holiday
        }
        
        csv += "\n"
        csv += csvLine([
            "TOTAL",
            String(yearWorkDays),
            decimal(yearTotalHours),
            formatOvertime(yearTotalOvertime),
            String(yearVacation),
            String(yearSick),
            String(yearHoliday)
        ]) + "\n"
        
        // Statistiques supplémentaires
        csv += "\n\nStatistiques\n"
        csv += csvLine(["Moyenne heures/jour", decimal(yearWorkDays > 0 ? yearTotalHours / Double(yearWorkDays) : 0)]) + "\n"
        csv += csvLine(["Heures standard/semaine", decimal(settings.weeklyHours)]) + "\n"
        csv += csvLine(["Jours de congés annuels", String(settings.annualVacationDays)]) + "\n"
        
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
            let hours = day.type == .work ? decimal(day.totalHours) : "-"
            let overtime = day.type == .work ? formatOvertime(day.overtimeSeconds) : "-"
            
            csv += csvLine([date, dayName, type, start, end, breakMin, hours, overtime]) + "\n"
            
            if day.type == .work {
                totalHours += day.totalHours
            }
            totalOvertime += day.overtimeSeconds
        }
        
        csv += "\n"
        csv += csvLine(["TOTAL", "", "", "", "", "", decimal(totalHours), formatOvertime(totalOvertime)]) + "\n"
        
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
            
            csv += csvLine([
                String(year),
                decimal(carryIn, fractionDigits: 1),
                decimal(entitlement, fractionDigits: 1),
                decimal(used, fractionDigits: 1),
                decimal(balance, fractionDigits: 1)
            ]) + "\n"
            
            carryIn = balance
        }
        
        csv += "\n"
        csv += csvLine(["Solde actuel", "\(decimal(carryIn, fractionDigits: 1)) jours"]) + "\n"
        
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
            csv += csvLine([date, type, String(year)]) + "\n"
        }
        
        return csv
    }
    
    /// Génère un rapport des heures supplémentaires
    func generateOvertimeReport(workDays: [WorkDay]) -> String {
        let calendar = Calendar.current
        
        let workOnlyDays = workDays.filter {
            $0.type == .work
        }
        let dailyGroups = Dictionary(grouping: workOnlyDays) {
            calendar.startOfDay(for: $0.date)
        }.sorted { $0.key < $1.key }
        
        var csv = "Rapport des heures supplémentaires\n\n"
        csv += "Date;Heures travaillées;Heures sup.;Cumul\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        var cumulative = 0
        
        for (dayDate, entries) in dailyGroups {
            let date = dateFormatter.string(from: dayDate)
            let hours = decimal(entries.reduce(0) { $0 + $1.totalHours })
            let overtime = entries.reduce(0) { $0 + $1.overtimeSeconds }
            cumulative += overtime
            
            csv += csvLine([date, hours, formatOvertime(overtime), formatOvertime(cumulative)]) + "\n"
        }
        
        csv += "\n"
        csv += csvLine(["Total heures supplémentaires", formatOvertime(cumulative)]) + "\n"
        
        // Résumé par année
        csv += "\n\nRésumé par année\n"
        csv += "Année;Heures sup.\n"
        
        let years = Set(workOnlyDays.map { calendar.component(.year, from: $0.date) }).sorted()
        
        for year in years {
            let yearOvertime = workOnlyDays
                .filter { calendar.component(.year, from: $0.date) == year }
                .reduce(0) { $0 + $1.overtimeSeconds }
            csv += csvLine([String(year), formatOvertime(yearOvertime)]) + "\n"
        }
        
        return csv
    }
    
    // MARK: - File Creation

    func csvData(content: String) -> Data? {
        ("\u{FEFF}" + content).data(using: .utf8)
    }
    
    func createCSVFile(content: String, filename: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(filename).csv")

        do {
            guard let data = csvData(content: content) else { return nil }
            try data.write(to: fileURL, options: .atomic)
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

    private func csv(_ rows: [[String]]) -> String {
        rows.map(csvLine).joined(separator: "\n") + "\n"
    }

    private func csvLine(_ fields: [String]) -> String {
        fields.map(escapedField).joined(separator: delimiter)
    }

    private func escapedField(_ field: String) -> String {
        var normalized = field
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let requiresQuotes = normalized.contains(delimiter)
            || normalized.contains("\"")
            || normalized.contains("\n")

        normalized = normalized.replacingOccurrences(of: "\"", with: "\"\"")
        return requiresQuotes ? "\"\(normalized)\"" : normalized
    }

    private func decimal(_ value: Double, fractionDigits: Int = 2) -> String {
        String(format: "%.\(fractionDigits)f", locale: Locale(identifier: "en_US_POSIX"), value)
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
