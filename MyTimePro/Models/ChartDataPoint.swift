import Foundation

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let hours: Double
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
}