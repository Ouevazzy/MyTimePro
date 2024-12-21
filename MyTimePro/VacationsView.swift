import SwiftUI
import SwiftData

struct VacationsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var userSettings = UserSettings.shared
    
    // Fetch request pour les congés
    @Query(filter: #Predicate<WorkDay> { workDay in
        workDay.type.isVacation && !workDay.isDeleted
    }, sort: \WorkDay.date) private var vacations: [WorkDay]
    
    // Fetch request pour les RTT
    @Query(filter: #Predicate<WorkDay> { workDay in
        workDay.type == .compensatory && !workDay.isDeleted
    }, sort: \WorkDay.date) private var compensatoryDays: [WorkDay]
    
    // Année actuelle
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    // Congés de l'année en cours
    private var currentYearVacations: [WorkDay] {
        vacations.filter { Calendar.current.component(.year, from: $0.date) == currentYear }
    }
    
    // RTT de l'année en cours
    private var currentYearCompensatory: [WorkDay] {
        compensatoryDays.filter { Calendar.current.component(.year, from: $0.date) == currentYear }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                statsView
                    .padding()
                
                if !compensatoryDays.isEmpty {
                    compensatoryView
                }
                
                if !vacations.isEmpty {
                    vacationsView
                }
            }
            .navigationTitle("Congés")
        }
    }
    
    // Vue des statistiques
    private var statsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Vue d'ensemble \(currentYear)")
                .font(.headline)
            
            HStack(spacing: 12) {
                let remainingDays = userSettings.annualVacationDays - Double(currentYearVacations.count)
                let totalRTT = currentYearCompensatory.count
                let totalExtra = currentYearCompensatory.reduce(0.0) { sum, day in
                    sum + abs(Double(day.overtimeSeconds) / 3600.0)
                }
                
                StatBox(
                    title: "Jours de congés restants",
                    value: String(format: "%.1f", remainingDays),
                    color: .blue
                )
                
                StatBox(
                    title: "RTT cumulés",
                    value: "\(totalRTT)",
                    color: .green
                )
            }
        }
    }
    
    // Vue des RTT
    private var compensatoryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RTT")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(compensatoryDays) { workDay in
                        CompensatoryCard(workDay: workDay)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    
    // Vue des congés
    private var vacationsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Congés")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vacations) { workDay in
                        VacationCard(workDay: workDay)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

// Carte pour RTT
struct CompensatoryCard: View {
    let workDay: WorkDay
    
    var body: some View {
        VStack(spacing: 12) {
            Text(workDay.date.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)
            
            Text(workDay.formattedOvertimeHours)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10)
    }
}

// Carte pour Congés
struct VacationCard: View {
    let workDay: WorkDay
    
    var body: some View {
        VStack(spacing: 12) {
            Text(workDay.date.formatted(date: .abbreviated, time: .omitted))
                .font(.headline)
            
            Text(workDay.type.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10)
    }
}
