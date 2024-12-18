import SwiftUI

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
