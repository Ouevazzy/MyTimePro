import SwiftUI
import SwiftData

private enum VacationFormatters {
    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = .autoupdatingCurrent
        return formatter
    }()
}

struct StatsBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var hoursValue: String? = nil
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        VStack(spacing: 6) {
            // Icône style Apple Settings
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: DS.IconSize.inline, height: DS.IconSize.inline)
                .background(color, in: RoundedRectangle(cornerRadius: DS.IconRadius.inline))
                .scaleEffect(reduceMotion ? 1 : (animate ? 1 : 0.8))
                .opacity(reduceMotion ? 1 : (animate ? 1 : 0))
                .accessibilityHidden(true)

            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            if let hoursValue {
                Text(hoursValue)
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.8))
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
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
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7).delay(0.1), value: animate)
        .onAppear {
            animate = true
        }
    }
}

struct VacationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<WorkDay> {
        !$0.isDeleted &&
        ($0.typeRawValue == "workDayType.vacation" || $0.typeRawValue == "workDayType.halfDayVacation")
    }, sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]
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
    private var selectedYearWorkDays: [WorkDay] {
        let calendar = Calendar.current
        return workDays.filter {
            calendar.component(.year, from: $0.date) == selectedYear
        }
    }

    private var startYear: Int {
        Calendar.current.component(.year, from: settings.vacationStartDate)
    }

    private var isStartYear: Bool {
        selectedYear == startYear
    }

    private var yearlyStats: YearlyVacationStats {
        let entitlement = Double(settings.annualVacationDays)
        let stats = VacationCalculations.remainingStats(for: selectedYear, workDays: workDays, annualEntitlement: entitlement)
        
        // Calculer les droits pour l'année sélectionnée
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
                    .foregroundStyle(.blue)
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
                        .foregroundStyle(.blue.opacity(0.7))
                }
                    .foregroundStyle(.primary)
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
                    .foregroundStyle(.blue)
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
                    if isStartYear {
                        // Pour l'année de début : afficher le solde initial
                        StatsBox(
                            title: "vacation.initialBalance".localized,
                            value: formatDaysValue(yearlyStats.carryIn),
                            icon: "star.fill",
                            color: Color.purple,
                            hoursValue: formatDaysAsHours(yearlyStats.carryIn)
                        )
                    } else {
                        // Pour les années suivantes : afficher droits + report
                        StatsBox(
                            title: "vacation.annualEntitlement".localized,
                            value: formatDaysValue(yearlyStats.annualEntitlement),
                            icon: "calendar.badge.plus",
                            color: Color.blue,
                            hoursValue: formatDaysAsHours(yearlyStats.annualEntitlement)
                        )

                        StatsBox(
                            title: "vacation.carryIn".localized,
                            value: formatDaysValue(yearlyStats.carryIn),
                            icon: "arrowshape.turn.up.right.fill",
                            color: Color.purple,
                            hoursValue: formatDaysAsHours(yearlyStats.carryIn)
                        )
                    }
                }

                HStack(spacing: 12) {
                    StatsBox(
                        title: "vacation.used".localized,
                        value: formatDaysValue(yearlyStats.totalDays),
                        icon: "checkmark.circle",
                        color: Color.green,
                        hoursValue: formatDaysAsHours(yearlyStats.totalDays)
                    )

                    StatsBox(
                        title: "vacation.remaining".localized,
                        value: formatDaysValue(yearlyStats.remainingDays),
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
        VStack(spacing: 4) {
            if isStartYear {
                Text("vacation.calculation.initial".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("vacation.initialDate.label".localized(VacationFormatters.mediumDate.string(from: settings.vacationStartDate)))
                    .font(.caption2)
                    .foregroundStyle(.blue)
            } else {
                Text("vacation.calculation.standard".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text("vacation.carryover.note".localized)
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.8))
        }
    }
    
    /// Convertit un nombre de jours en heures formatées
    private func formatDaysValue(_ days: Double) -> String {
        String(format: "%.1f %@", days, "time.days.short".localized)
    }

    private func formatDaysAsHours(_ days: Double) -> String {
        let hours = days * settings.standardDailyHours
        if settings.useDecimalHours {
            return String(format: "%.1f%@", hours, "time.hours.short".localized)
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
            let filteredWorkDays = selectedYearWorkDays
            
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
                    VacationRow(workDay: workDay, standardDailyHours: settings.standardDailyHours)
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
    let standardDailyHours: Double
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    private var days: Double {
        workDay.type == .vacation ? 1.0 : 0.5
    }

    private var durationLabel: String {
        workDay.type == .vacation ? "vacation.fullDay".localized : "vacation.halfDay".localized
    }
    
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
                Text(workDay.type.localizedName)
                    .font(.headline)
                
                HStack(spacing: 6) {
                    Text(VacationFormatters.mediumDate.string(from: workDay.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    let hours = days * standardDailyHours
                    Text("\(durationLabel) (\(String(format: "%.1f%@", hours, "time.hours.short".localized)))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
                
                if let note = workDay.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            Spacer()
            
            // Chevron de navigation
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .opacity(reduceMotion ? 1 : (animate ? 1 : 0))
        .offset(x: reduceMotion ? 0 : (animate ? 0 : -20))
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7), value: animate)
        .onAppear {
            animate = true
        }
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
