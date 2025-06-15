import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]
    
    @State private var selectedYear: Int
    let settings = UserSettings.shared
    
    init() {
        let currentYear = Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: currentYear)
    }
    
    var yearlyStats: YearStats {
        calculateYearStats(for: selectedYear)
    }
    
    // Nouvelle propriété calculant le cumul des heures supp. (années précédentes + année en cours)
    var cumulativeOvertimeSeconds: Int {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: selectedYear))!
        // Filtrer les WorkDay avant le début de l'année sélectionnée
        let previousDays = workDays.filter { $0.date < startDate }
        let previousOvertime = previousDays.reduce(0) { $0 + $1.overtimeSeconds }
        return previousOvertime + yearlyStats.overtimeSeconds
    }
    
    var monthlyStats: [MonthStats] {
        (1...12).map { month in
            calculateMonthStats(year: selectedYear, month: month)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // En-tête avec le nom de l'année et navigation
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
                    
                    Text("\(selectedYear)")
                        .font(.title)
                    
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
                
                // Statistiques annuelles en grille
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        icon: "briefcase.fill",
                        iconColor: .blue,
                        value: "\(yearlyStats.workDays)",
                        title: "Jours travaillés"
                    )
                    StatCard(
                        icon: "umbrella.fill",
                        iconColor: .orange,
                        value: String(format: "%.1f", yearlyStats.vacationDays),
                        title: "Congés"
                    )
                    StatCard(
                        icon: "cross.fill",
                        iconColor: .red,
                        value: "\(yearlyStats.sickDays)",
                        title: "Maladie"
                    )
                    StatCard(
                        icon: "clock.fill",
                        iconColor: .blue,
                        value: WorkTimeCalculations.formattedTimeInterval(yearlyStats.totalHours * 3600),
                        title: "Total heures"
                    )
                    // Carte des heures supp. avec affichage du cumul
                    StatCard(
                        icon: "clock.badge.exclamationmark.fill",
                        iconColor: yearlyStats.overtimeSeconds >= 0 ? .green : .red,
                        value: WorkTimeCalculations.formattedTimeInterval(Double(yearlyStats.overtimeSeconds)),
                        title: "Heures supp.",
                        subtitle: "Cumul: " + WorkTimeCalculations.formattedTimeInterval(Double(cumulativeOvertimeSeconds))
                    )
                    StatCard(
                        icon: "dollarsign.circle.fill",
                        iconColor: .orange,
                        value: String(format: "%.0f CHF", yearlyStats.totalBonus),
                        title: "Bonus"
                    )
                }
                .padding()
                
                // Liste des mois
                List {
                    ForEach(monthlyStats) { monthStat in
                        Section(header:
                            HStack {
                                Text(monthStat.monthName)
                                    .font(.title2)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(monthStat.workDays) jours")
                                    .foregroundStyle(.secondary)
                            }
                            .textCase(nil)
                        ) {
                            VStack(spacing: 16) {
                                Grid(alignment: .leading, horizontalSpacing: 50, verticalSpacing: 16) {
                                    GridRow {
                                        VStack(alignment: .leading) {
                                            Text("Heures travaillées")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            Text(WorkTimeCalculations.formattedTimeInterval(monthStat.totalHours * 3600))
                                                .font(.body)
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text("Heures supp.")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            Text(WorkTimeCalculations.formattedTimeInterval(Double(monthStat.overtimeSeconds)))
                                                .font(.body)
                                                .foregroundStyle(monthStat.overtimeSeconds >= 0 ? .green : .red)
                                        }
                                    }
                                    
                                    GridRow {
                                        VStack(alignment: .leading) {
                                            Text("Congés pris")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            Text(String(format: "%.1f jours", monthStat.vacationDays))
                                                .font(.body)
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text("Jours maladie")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            Text("\(monthStat.sickDays) jours")
                                                .font(.body)
                                        }
                                    }
                                }
                                
                                if monthStat.totalBonus > 0 {
                                    HStack {
                                        Text("Total bonus")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(String(format: "%.2f", monthStat.totalBonus))
                                            .font(.body)
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Statistiques")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func calculateYearStats(for year: Int) -> YearStats {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: year))!
        let endDate = calendar.date(byAdding: .year, value: 1, to: startDate)!
        
        let yearWorkDays = workDays.filter { $0.date >= startDate && $0.date < endDate }
        
        let workDaysCount = yearWorkDays.filter { $0.type == .work }.count
        let vacationDays = yearWorkDays.reduce(0.0) { total, day in
            if day.type == .vacation {
                return total + 1
            } else if day.type == .halfDayVacation {
                return total + 0.5
            }
            return total
        }
        let sickDays = yearWorkDays.filter { $0.type == .sickLeave }.count
        
        let totalHours = yearWorkDays.reduce(0.0) { $0 + $1.totalHours }
        let overtimeSeconds = yearWorkDays.reduce(0) { $0 + $1.overtimeSeconds }
        let totalBonus = yearWorkDays.reduce(0.0) { $0 + $1.bonusAmount }
        
        return YearStats(
            workDays: workDaysCount,
            vacationDays: vacationDays,
            sickDays: sickDays,
            totalHours: totalHours,
            overtimeSeconds: overtimeSeconds,
            totalBonus: totalBonus
        )
    }
    
    private func calculateMonthStats(year: Int, month: Int) -> MonthStats {
        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: year, month: month))!
        let endDate = calendar.date(byAdding: .month, value: 1, to: startDate)!
        
        let monthWorkDays = workDays.filter { $0.date >= startDate && $0.date < endDate }
        
        let workDaysCount = monthWorkDays.filter { $0.type == .work }.count
        let vacationDays = monthWorkDays.reduce(0.0) { total, day in
            if day.type == .vacation {
                return total + 1
            } else if day.type == .halfDayVacation {
                return total + 0.5
            }
            return total
        }
        let sickDays = monthWorkDays.filter { $0.type == .sickLeave }.count
        
        let totalHours = monthWorkDays.reduce(0.0) { $0 + $1.totalHours }
        let overtimeSeconds = monthWorkDays.reduce(0) { $0 + $1.overtimeSeconds }
        let totalBonus = monthWorkDays.reduce(0.0) { $0 + $1.bonusAmount }
        
        return MonthStats(
            month: month,
            workDays: workDaysCount,
            vacationDays: vacationDays,
            sickDays: sickDays,
            totalHours: totalHours,
            overtimeSeconds: overtimeSeconds,
            totalBonus: totalBonus
        )
    }
}

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let title: String
    let subtitle: String?
    
    // Le paramètre "subtitle" est optionnel, avec une valeur par défaut nil
    init(icon: String, iconColor: Color, value: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.value = value
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
            Text(value)
                .font(.title2)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct YearStats {
    let workDays: Int
    let vacationDays: Double
    let sickDays: Int
    let totalHours: Double
    let overtimeSeconds: Int
    let totalBonus: Double
}

struct MonthStats: Identifiable {
    let id = UUID()
    let month: Int
    let workDays: Int
    let vacationDays: Double
    let sickDays: Int
    let totalHours: Double
    let overtimeSeconds: Int
    let totalBonus: Double
    
    var monthName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "fr_FR")
        return dateFormatter.monthSymbols[month - 1].capitalized
    }
}

#Preview {
    StatsView()
        .modelContainer(for: WorkDay.self, inMemory: true)
}
