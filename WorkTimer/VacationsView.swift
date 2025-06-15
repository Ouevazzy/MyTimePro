import SwiftUI
import SwiftData

struct StatsBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}

struct VacationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]
    @State private var selectedYear: Int
    
    let settings = UserSettings.shared
    
    // Plage d'années fixe de -5 ans à +5 ans par rapport à l'année courante
    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...(currentYear + 5))
    }
    
    init() {
        let currentYear = Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: currentYear)
    }
    
    // MARK: - Computed Properties
    private var yearlyStats: YearlyVacationStats {
        let filteredWorkDays = workDays.filter { workDay in
            Calendar.current.component(.year, from: workDay.date) == selectedYear
        }
        
        let vacationDays = filteredWorkDays.reduce(0.0) { total, day in
            switch day.type {
            case .vacation:
                return total + 1
            case .halfDayVacation:
                return total + 0.5
            default:
                return total
            }
        }
        
        return YearlyVacationStats(
            totalDays: vacationDays,
            remainingDays: Double(settings.annualVacationDays) - vacationDays
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // En-tête avec sélecteur d'année et navigation
                yearSelector
                
                // Statistiques annuelles
                statsHeader
                
                Divider()
                
                // Liste des congés
                vacationsList
            }
            .navigationTitle("Congés")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var yearSelector: some View {
        HStack {
            Button(action: {
                withAnimation {
                    selectedYear -= 1
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            Menu {
                ForEach(availableYears, id: \.self) { year in
                    Button(String(year)) {
                        selectedYear = year
                    }
                }
            } label: {
                Text("\(selectedYear)")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    selectedYear += 1
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private var statsHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatsBox(
                    title: "Solde restant",
                    value: String(format: "%.1f j", yearlyStats.remainingDays),
                    icon: "calendar.badge.clock",
                    color: Color.blue
                )
                
                StatsBox(
                    title: "Utilisés",
                    value: String(format: "%.1f j", yearlyStats.totalDays),
                    icon: "checkmark.circle",
                    color: Color.green
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var vacationsList: some View {
        List {
            let filteredWorkDays = workDays.filter {
                Calendar.current.component(.year, from: $0.date) == selectedYear &&
                ($0.type == .vacation || $0.type == .halfDayVacation)
            }.sorted(by: { $0.date > $1.date })
            
            if filteredWorkDays.isEmpty {
                Text("Aucun congé pour cette année")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(filteredWorkDays) { workDay in
                    VacationRow(workDay: workDay)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct VacationRow: View {
    let workDay: WorkDay
    
    var body: some View {
        HStack {
            Image(systemName: workDay.type == .vacation ? "sun.max.fill" : "sun.min.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workDay.type == .vacation ? "Congé" : "Demi-journée")
                    .font(.headline)
                
                HStack {
                    Text(formatDate(workDay.date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(workDay.type == .vacation ? "1 j" : "0.5 j")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let note = workDay.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        dateFormatter.locale = Locale(identifier: "fr_FR")
        return dateFormatter.string(from: date)
    }
}

// MARK: - Supporting Types
struct YearlyVacationStats {
    let totalDays: Double
    let remainingDays: Double
}

// MARK: - Preview
#Preview {
    VacationsView()
        .modelContainer(for: WorkDay.self, inMemory: true)
}
