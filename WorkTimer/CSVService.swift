//
//  CSVService.swift
//  WorkTimer
//
//  Service d'export des données au format CSV
//

import Foundation

class CSVService {

    // MARK: - Singleton
    static let shared = CSVService()
    private let delimiter = ";"
    private init() {}
    
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
    
    // MARK: - File Creation

    func csvData(content: String) -> Data? {
        ("\u{FEFF}" + content).data(using: .utf8)
    }
    
    // MARK: - Helpers
    
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
