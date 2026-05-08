import SwiftUI
import SwiftData

struct StatsBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var hoursValue: String? = nil
    @Environment(\.colorScheme) var colorScheme
    @State private var animate = false

    var body: some View {
        VStack(spacing: 6) {
            // Icône style Apple Settings
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: DS.IconSize.inline, height: DS.IconSize.inline)
                .background(color, in: RoundedRectangle(cornerRadius: DS.IconRadius.inline))
                .scaleEffect(animate ? 1 : 0.8)
                .opacity(animate ? 1 : 0)
                .accessibilityHidden(true)

            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            if let hoursValue {
                Text(hoursValue)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
        .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1), value: animate)
        .onAppear {
            animate = true
        }
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
        let entitlement = Double(settings.annualVacationDays)
        let stats = VacationCalculations.remainingStats(for: selectedYear, workDays: workDays, annualEntitlement: entitlement)
        
        // Calculer les droits pour l'année sélectionnée
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: settings.vacationStartDate)
        
        let currentYearEntitlement: Double
        if selectedYear == startYear {
            // Pour l'année de début : le solde initial contient DÉJÀ tout ce qui était disponible
            // Les "droits" affichés = 0 (pas de droits supplémentaires)
            currentYearEntitlement = 0
        } else if selectedYear < startYear {
            // Pour les années antérieures à l'année de début, pas de droits
            currentYearEntitlement = 0
        } else {
            // Pour les années après l'année de début, droits complets
            currentYearEntitlement = entitlement
        }
        
        return YearlyVacationStats(
            totalDays: stats.used,
            remainingDays: stats.remaining,
            carryIn: stats.carryIn,
            annualEntitlement: currentYearEntitlement
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
            .navigationTitle("navigation.vacations".localized)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Analytics.shared.logScreenView("vacations")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.close".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var yearSelector: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    selectedYear -= 1
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            
            Spacer()
            
            Menu {
                ForEach(availableYears, id: \.self) { year in
                    Button(String(year)) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        selectedYear = year
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                Text(verbatim: "\(selectedYear)")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue.opacity(0.7))
                }
                    .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    selectedYear += 1
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private var statsHeader: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    let calendar = Calendar.current
                    let startYear = calendar.component(.year, from: settings.vacationStartDate)
                    let isStartYear = selectedYear == startYear
                    
                    if isStartYear {
                        // Pour l'année de début : afficher le solde initial
                        StatsBox(
                            title: "vacation.initialBalance".localized,
                            value: String(format: "%.1f j", yearlyStats.carryIn),
                            icon: "star.fill",
                            color: Color.purple,
                            hoursValue: formatDaysAsHours(yearlyStats.carryIn)
                        )
                    } else {
                        // Pour les années suivantes : afficher droits + report
                        StatsBox(
                            title: "vacation.annualEntitlement".localized,
                            value: String(format: "%.1f j", yearlyStats.annualEntitlement),
                            icon: "calendar.badge.plus",
                            color: Color.blue,
                            hoursValue: formatDaysAsHours(yearlyStats.annualEntitlement)
                        )

                        StatsBox(
                            title: "vacation.carryIn".localized,
                            value: String(format: "%.1f j", yearlyStats.carryIn),
                            icon: "arrowshape.turn.up.right.fill",
                            color: Color.purple,
                            hoursValue: formatDaysAsHours(yearlyStats.carryIn)
                        )
                    }
                }

                HStack(spacing: 12) {
                    StatsBox(
                        title: "vacation.used".localized,
                        value: String(format: "%.1f j", yearlyStats.totalDays),
                        icon: "checkmark.circle",
                        color: Color.green,
                        hoursValue: formatDaysAsHours(yearlyStats.totalDays)
                    )

                    StatsBox(
                        title: "vacation.remaining".localized,
                        value: String(format: "%.1f j", yearlyStats.remainingDays),
                        icon: "calendar.badge.clock",
                        color: yearlyStats.remainingDays > 0 ? Color.orange : Color.red,
                        hoursValue: formatDaysAsHours(yearlyStats.remainingDays)
                    )
                }
            }
            .padding(.horizontal)
            
            vacationExplanationView
            .padding(.top, 4)
        }
        .padding(.vertical)
        .background(Color(.systemGroupedBackground))
    }
    
    private var vacationExplanationView: some View {
        let calendar = Calendar.current
        let startYear = calendar.component(.year, from: settings.vacationStartDate)
        let isStartYear = selectedYear == startYear
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = Locale(identifier: "fr_FR")
        
        return VStack(spacing: 4) {
            if isStartYear {
                Text("Solde restant = Solde initial - Utilisés")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Solde initial saisi pour le \(dateFormatter.string(from: settings.vacationStartDate))")
                    .font(.caption2)
                    .foregroundColor(.blue)
            } else {
                Text("Solde restant = Droits annuels + Report - Utilisés")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Le solde restant est reporté à l'année suivante")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.8))
        }
    }
    
    /// Convertit un nombre de jours en heures formatées
    private func formatDaysAsHours(_ days: Double) -> String {
        let hours = days * settings.standardDailyHours
        if settings.useDecimalHours {
            return String(format: "%.1fh", hours)
        } else {
            let totalMinutes = Int(round(hours * 60))
            let h = abs(totalMinutes / 60)
            let m = abs(totalMinutes % 60)
            let sign = hours < 0 ? "-" : ""
            return String(format: "%@%dh%02d", sign, h, m)
        }
    }

    private var vacationsList: some View {
        List {
            let filteredWorkDays = workDays.filter {
                Calendar.current.component(.year, from: $0.date) == selectedYear &&
                ($0.type == .vacation || $0.type == .halfDayVacation)
            }.sorted(by: { $0.date > $1.date })
            
            if filteredWorkDays.isEmpty {
                EmptyStateView(
                    icon: "sun.max.trianglebadge.exclamationmark",
                    title: "vacation.empty.title".localized,
                    subtitle: "vacation.empty.message".localized(selectedYear),
                    iconColors: [.orange, .yellow]
                )
                    .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } else {
                ForEach(filteredWorkDays) { workDay in
                    VacationRow(workDay: workDay)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

struct VacationRow: View {
    let workDay: WorkDay
    @Environment(\.colorScheme) var colorScheme
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icône avec fond arrondi
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.25), .yellow.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: workDay.type == .vacation ? "sun.max.fill" : "sun.min.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workDay.type == .vacation ? "Congé" : "Demi-journée")
                    .font(.headline)
                
                HStack(spacing: 6) {
                    Text(formatDate(workDay.date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    let days: Double = workDay.type == .vacation ? 1.0 : 0.5
                    let hours = days * UserSettings.shared.standardDailyHours
                    Text(String(format: workDay.type == .vacation ? "1 jour (%.1fh)" : "0.5 jour (%.1fh)", hours))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                
                if let note = workDay.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Chevron de navigation
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .opacity(animate ? 1 : 0)
        .offset(x: animate ? 0 : -20)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: animate)
        .onAppear {
            animate = true
        }
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
    let carryIn: Double
    let annualEntitlement: Double
}

// MARK: - Preview
#Preview {
    VacationsView()
        .modelContainer(for: WorkDay.self, inMemory: true)
}
