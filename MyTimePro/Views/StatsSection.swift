import SwiftUI

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
