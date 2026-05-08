import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedYear: Int
    let settings = UserSettings.shared

    init() {
        let currentYear = Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: currentYear)
    }

    @State private var yearlyStats: YearStats = .empty
    @State private var monthlyStats: [MonthStats] = []

    var body: some View {
        VStack(spacing: 0) {
            // Grille des statistiques annuelles
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DS.Spacing.sm) {
                StatCard(
                    icon: "briefcase.fill",
                    iconColor: .blue,
                    value: "\(yearlyStats.workDays)",
                    title: "stats.workDays".localized
                )
                .equatable()
                StatCard(
                    icon: "umbrella.fill",
                    iconColor: .orange,
                    value: String(format: "%.1f j", yearlyStats.vacationDays),
                    title: "stats.vacationDays".localized,
                    subtitle: formatDaysAsHours(yearlyStats.vacationDays)
                )
                .equatable()
                StatCard(
                    icon: "cross.fill",
                    iconColor: .red,
                    value: "\(yearlyStats.sickDays)",
                    title: "stats.sickDays".localized
                )
                .equatable()
                StatCard(
                    icon: "clock.fill",
                    iconColor: .blue,
                    value: WorkTimeCalculations.formattedHoursRounded(yearlyStats.totalHours),
                    title: "stats.totalHours".localized
                )
                .equatable()
                StatCard(
                    icon: "clock.badge.exclamationmark.fill",
                    iconColor: yearlyStats.overtimeSeconds >= 0 ? .green : .red,
                    value: WorkTimeCalculations.formattedSecondsRounded(yearlyStats.overtimeSeconds),
                    title: "stats.overtimeHours".localized
                )
                .equatable()
                StatCard(
                    icon: "dollarsign.circle.fill",
                    iconColor: .orange,
                    value: String(format: "%.0f CHF", yearlyStats.totalBonus),
                    title: "stats.bonus".localized
                )
                .equatable()
            }
            .padding(.horizontal)
            .padding(.vertical, DS.Spacing.sm)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
            .padding(.horizontal)
            .padding(.vertical, DS.Spacing.sm)

            // Liste des mois
            List {
                if monthlyStats.allSatisfy({ $0.workDays == 0 && $0.vacationDays == 0 && $0.sickDays == 0 }) {
                    Section {
                        VStack(spacing: DS.Spacing.md) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text(String(format: "stats.noData".localized, selectedYear))
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("stats.noDataHelp".localized)
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                ForEach(monthlyStats) { monthStat in
                    Section {
                        MonthStatContent(
                            monthStat: monthStat,
                            formattedHours: WorkTimeCalculations.formattedHoursRounded(monthStat.totalHours),
                            formattedOvertime: WorkTimeCalculations.formattedSecondsRounded(monthStat.overtimeSeconds),
                            formattedVacation: String(format: "%.1f", monthStat.vacationDays) + " " + "time.days".localized + " (" + formatDaysAsHours(monthStat.vacationDays) + ")",
                            formattedBonus: String(format: "%.2f", monthStat.totalBonus),
                            isOvertimePositive: monthStat.overtimeSeconds >= 0
                        )
                        .equatable()
                    } header: {
                        HStack {
                            Text(monthStat.monthName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Spacer()
                            if monthStat.workDays > 0 {
                                Text("\(monthStat.workDays) \("time.days".localized)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .textCase(nil)
                        .padding(.top, DS.Spacing.xs)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                StatsCache.shared.invalidateYear(selectedYear)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    guard selectedYear > 2000 else { return }
                    withAnimation(DS.Animation.navigation) { selectedYear -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("accessibility.previousYear".localized)
                .accessibilityHint(String(format: "accessibility.yearStats".localized, selectedYear - 1))
            }
            ToolbarItem(placement: .principal) {
                Text(verbatim: "\(selectedYear)")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    guard selectedYear < 2100 else { return }
                    withAnimation(DS.Animation.navigation) { selectedYear += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("accessibility.nextYear".localized)
                .accessibilityHint(String(format: "accessibility.yearStats".localized, selectedYear + 1))
            }
        }
        .task(id: selectedYear) {
            yearlyStats = calculateYearStats(for: selectedYear)
            monthlyStats = (1...12).map { calculateMonthStats(year: selectedYear, month: $0) }
        }
    }

    // MARK: - Formatting

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

    // MARK: - Calculations

    private func calculateYearStats(for year: Int) -> YearStats {
        let cache = StatsCache.shared
        if let cached = cache.getYearlyStats(for: year) {
            return YearStats(workDays: cached.workDays, vacationDays: cached.vacationDays, sickDays: cached.sickDays,
                             totalHours: cached.totalHours, overtimeSeconds: cached.overtimeSeconds, totalBonus: cached.totalBonus)
        }

        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: year))!
        let endDate = calendar.date(byAdding: .year, value: 1, to: startDate)!

        var workDaysCount = 0; var vacationDays = 0.0; var sickDays = 0
        var totalHours = 0.0; var overtimeSeconds = 0; var totalBonus = 0.0

        let days = fetchWorkDays(from: startDate, to: endDate, order: .forward)

        for day in days {
            switch day.type {
            case .work:            workDaysCount += 1
            case .vacation:        vacationDays += 1.0
            case .halfDayVacation: vacationDays += 0.5
            case .sickLeave:       sickDays += 1
            default: break
            }
            totalHours += day.totalHours
            overtimeSeconds += day.overtimeSeconds
            totalBonus += day.bonusAmount
        }

        cache.cacheYearlyStats(year: year, workDays: workDaysCount, vacationDays: vacationDays,
                               sickDays: sickDays, totalHours: totalHours, overtimeSeconds: overtimeSeconds, totalBonus: totalBonus)

        return YearStats(workDays: workDaysCount, vacationDays: vacationDays, sickDays: sickDays,
                         totalHours: totalHours, overtimeSeconds: overtimeSeconds, totalBonus: totalBonus)
    }

    private func calculateMonthStats(year: Int, month: Int) -> MonthStats {
        let cache = StatsCache.shared
        if let cached = cache.getMonthlyStats(year: year, month: month) {
            return MonthStats(month: month, workDays: cached.workDays,
                              vacationDays: cached.vacationDays, sickDays: cached.sickDays,
                              totalHours: cached.totalHours, overtimeSeconds: cached.overtimeSeconds,
                              totalBonus: cached.totalBonus)
        }

        let calendar = Calendar.current
        let startDate = calendar.date(from: DateComponents(year: year, month: month))!
        let endDate = calendar.date(byAdding: .month, value: 1, to: startDate)!

        var workDaysCount = 0; var vacationDays = 0.0; var sickDays = 0
        var totalHours = 0.0; var overtimeSeconds = 0; var totalBonus = 0.0

        let days = fetchWorkDays(from: startDate, to: endDate, order: .forward)

        for day in days {
            switch day.type {
            case .work:            workDaysCount += 1
            case .vacation:        vacationDays += 1.0
            case .halfDayVacation: vacationDays += 0.5
            case .sickLeave:       sickDays += 1
            default: break
            }
            totalHours += day.totalHours
            overtimeSeconds += day.overtimeSeconds
            totalBonus += day.bonusAmount
        }

        cache.cacheMonthlyStats(year: year, month: month, workDays: workDaysCount,
                                vacationDays: vacationDays, sickDays: sickDays,
                                totalHours: totalHours, overtimeSeconds: overtimeSeconds, totalBonus: totalBonus)

        return MonthStats(month: month, workDays: workDaysCount, vacationDays: vacationDays, sickDays: sickDays,
                          totalHours: totalHours, overtimeSeconds: overtimeSeconds, totalBonus: totalBonus)
    }

    private func fetchWorkDays(from startDate: Date, to endDate: Date, order: SortOrder) -> [WorkDay] {
        let descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate<WorkDay> {
                $0.date >= startDate && $0.date < endDate
            },
            sortBy: [SortDescriptor(\.date, order: order)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            AppLogger.error("Stats fetch failed", category: AppLogger.data, error: error)
            return []
        }
    }
}

// MARK: - MonthStatContent

private struct MonthStatContent: View, Equatable {
    let monthStat: MonthStats
    let formattedHours: String
    let formattedOvertime: String
    let formattedVacation: String
    let formattedBonus: String
    let isOvertimePositive: Bool

    static func == (lhs: MonthStatContent, rhs: MonthStatContent) -> Bool {
        lhs.formattedHours == rhs.formattedHours &&
        lhs.formattedOvertime == rhs.formattedOvertime &&
        lhs.formattedVacation == rhs.formattedVacation &&
        lhs.formattedBonus == rhs.formattedBonus &&
        lhs.isOvertimePositive == rhs.isOvertimePositive &&
        lhs.monthStat.month == rhs.monthStat.month &&
        lhs.monthStat.vacationDays == rhs.monthStat.vacationDays &&
        lhs.monthStat.sickDays == rhs.monthStat.sickDays &&
        lhs.monthStat.totalBonus == rhs.monthStat.totalBonus
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.xl) {
                StatDataCell(
                    label: "stats.workedHours".localized,
                    value: formattedHours,
                    valueColor: .primary
                )
                StatDataCell(
                    label: "stats.overtimeHours".localized,
                    value: formattedOvertime,
                    valueColor: isOvertimePositive ? .green : .red
                )
            }

            if monthStat.vacationDays > 0 || monthStat.sickDays > 0 {
                HStack(spacing: DS.Spacing.xl) {
                    if monthStat.vacationDays > 0 {
                        StatDataCell(
                            label: "stats.vacationDays".localized,
                            value: formattedVacation,
                            valueColor: .primary
                        )
                    }
                    if monthStat.sickDays > 0 {
                        StatDataCell(
                            label: "stats.sickDays".localized,
                            value: "\(monthStat.sickDays) \("time.days".localized)",
                            valueColor: .primary
                        )
                    }
                    if monthStat.vacationDays == 0 || monthStat.sickDays == 0 {
                        Spacer()
                    }
                }
            }

            if monthStat.totalBonus > 0 {
                HStack {
                    Text("stats.bonus".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formattedBonus)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

private struct StatDataCell: View {
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - StatCard

struct StatCard: View, Equatable {
    let icon: String
    let iconColor: Color
    let value: String
    let title: String
    let subtitle: String?
    @State private var animate = false

    static func == (lhs: StatCard, rhs: StatCard) -> Bool {
        lhs.icon == rhs.icon &&
        lhs.iconColor == rhs.iconColor &&
        lhs.value == rhs.value &&
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle
    }

    init(icon: String, iconColor: Color, value: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.value = value
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: DS.Font.iconSmall, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: DS.IconSize.inline, height: DS.IconSize.inline)
                .background(iconColor, in: RoundedRectangle(cornerRadius: DS.IconRadius.inline))
                .accessibilityHidden(true)
                .scaleEffect(animate ? 1 : 0.8)
                .opacity(animate ? 1 : 0)

            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .scaleEffect(animate ? 1 : 0.9)
                .opacity(animate ? 1 : 0)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)" + (subtitle != nil ? ", \(subtitle!)" : ""))
        .animation(DS.Animation.appear.delay(0.1), value: animate)
        .onAppear { animate = true }
    }
}

// MARK: - Data Models

struct YearStats {
    let workDays: Int
    let vacationDays: Double
    let sickDays: Int
    let totalHours: Double
    let overtimeSeconds: Int
    let totalBonus: Double

    static let empty = YearStats(workDays: 0, vacationDays: 0, sickDays: 0,
                                 totalHours: 0, overtimeSeconds: 0, totalBonus: 0)
}

struct MonthStats: Identifiable {
    var id: Int { month }
    let month: Int
    let workDays: Int
    let vacationDays: Double
    let sickDays: Int
    let totalHours: Double
    let overtimeSeconds: Int
    let totalBonus: Double

    var monthName: String {
        Self.monthSymbols[month - 1]
    }

    private static let monthSymbols: [String] = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        return f.monthSymbols.map { $0.capitalized }
    }()
}

#Preview {
    NavigationStack {
        StatsView()
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}
