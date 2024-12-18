import SwiftUI
import SwiftData

struct HomeTabView: View {
    // MARK: - Environment & State Properties
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]
    @StateObject private var timerManager: WorkTimerManager = WorkTimerManager()
    @Environment(\.scenePhase) private var scenePhase
    
    // Le reste du code HomeTabView...
}

// MARK: - Supporting Views
struct RemainingTimeComponent: View {
    let time: TimeInterval
    
    var body: some View {
        Text(formatTime(time))
            .font(.system(.title2, design: .rounded))
            .foregroundColor(.secondary)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let roundedInterval = round(timeInterval)
        let hours = Int(roundedInterval) / 3600
        let minutes = Int(roundedInterval) / 60 % 60
        let seconds = Int(roundedInterval) % 60
        return String(format: "%dh%02dmin %02d", hours, minutes, seconds)
    }
}

struct StatsSection: View {
    let title: String
    let icon: String
    let color: Color
    let stats: (totalHours: Double, overtimeSeconds: Int)
    let showMissingHours: Bool
    
    private var overtimeText: String {
        showMissingHours ? "Heures manquantes" : "Heures supp."
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Heures travaillées")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(WorkTimeCalculations.formattedTimeInterval(stats.totalHours * 3600))
                        .font(.title)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text(overtimeText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(WorkTimeCalculations.formattedTimeInterval(Double(stats.overtimeSeconds)))
                        .font(.title)
                        .foregroundColor(stats.overtimeSeconds >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct VacationSection: View {
    let stats: (used: Double, remaining: Double)
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.orange)
                Text("Vacances")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Jours restants")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", stats.remaining))
                        .font(.title)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Jours utilisés")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", stats.used))
                        .font(.title)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
