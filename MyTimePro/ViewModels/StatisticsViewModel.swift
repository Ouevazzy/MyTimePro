import Foundation
import Combine
import CloudKit

class StatisticsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage: String?
    @Published var chartData: [ChartDataPoint] = []
    @Published var weekdayDistribution: [Int: Double] = [:]
    @Published var totalWorkedHours: Double = 0
    
    var totalHours: String {
        String(format: "%.1f h", totalWorkedHours)
    }
    
    var averageHoursPerDay: String {
        let average = totalWorkedHours / Double(chartData.count)
        return String(format: "%.1f h", average)
    }
    
    var workedDaysCount: String {
        "\(chartData.count) jours"
    }
    
    func loadStatistics(for period: StatisticsPeriod) async {
        await MainActor.run { isLoading = true }
        
        do {
            let timeRecords = try await CloudKitManager.shared.fetchTimeRecords(for: period.startDate)
            let statistics = calculateStatistics(from: timeRecords)
            
            await MainActor.run {
                self.chartData = statistics.chartData
                self.weekdayDistribution = statistics.weekdayDistribution
                self.totalWorkedHours = statistics.totalHours
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showingError = true
                self.isLoading = false
            }
        }
    }
    
    private func calculateStatistics(from records: [TimeRecord]) -> (chartData: [ChartDataPoint], weekdayDistribution: [Int: Double], totalHours: Double) {
        var chartData: [ChartDataPoint] = []
        var weekdayDistribution: [Int: Double] = [:]
        var totalHours: Double = 0
        
        // Grouper les enregistrements par date
        let groupedRecords = Dictionary(grouping: records) { record in
            Calendar.current.startOfDay(for: record.date)
        }
        
        for (date, records) in groupedRecords {
            let hoursForDay = records.reduce(0.0) { $0 + ($1.duration / 3600) }
            chartData.append(ChartDataPoint(date: date, hours: hoursForDay))
            totalHours += hoursForDay
            
            let weekday = Calendar.current.component(.weekday, from: date)
            weekdayDistribution[weekday, default: 0] += hoursForDay
        }
        
        return (chartData.sorted { $0.date < $1.date }, weekdayDistribution, totalHours)
    }
}