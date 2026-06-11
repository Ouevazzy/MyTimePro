import SwiftUI
import SwiftData

struct HomeTabView: View {
    // MARK: - Environment & State Properties
    @Environment(\.modelContext) private var modelContext

    // Seuls les jours de congé — nécessaires pour le calcul multi-année du report
    @Query(filter: #Predicate<WorkDay> {
        !$0.isDeleted &&
        ($0.typeRawValue == "workDayType.vacation" || $0.typeRawValue == "workDayType.halfDayVacation")
    }, sort: \WorkDay.date) private var vacationWorkDays: [WorkDay]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State Properties
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var selectedWeek: Date
    @State private var animateCards = false

    // Stats en cache — calculées via FetchDescriptor, jamais itérées dans body
    @State private var yearlyStats: (totalHours: Double, overtimeSeconds: Int) = (0, 0)
    @State private var monthlyStats: (totalHours: Double, overtimeSeconds: Int) = (0, 0)
    @State private var weeklyStats: (totalHours: Double, overtimeSeconds: Int) = (0, 0)
    @State private var vacationStats: (used: Double, remaining: Double, carryIn: Double, annual: Double) = (0, 0, 0, 0)
    @State private var isCurrentYearStartYear: Bool = false

    // MARK: - Constants
    let settings = UserSettings.shared

    // MARK: - Initialization
    init() {
        let currentDate = Date()
        let calendar = Calendar.current
        _selectedYear = State(initialValue: calendar.component(.year, from: currentDate))
        _selectedMonth = State(initialValue: calendar.component(.month, from: currentDate))
        _selectedWeek = State(initialValue: currentDate)
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                heroCard
                    .cardAppear(index: 0, animate: animateCards, reduceMotion: reduceMotion)

                statsCard(
                    title: "stats.year".localized(selectedYear),
                    icon: "calendar",
                    color: .blue,
                    stats: yearlyStats,
                    showMissing: false
                )
                .cardAppear(index: 1, animate: animateCards, reduceMotion: reduceMotion)

                statsCard(
                    title: "stats.currentMonth".localized,
                    icon: "calendar.badge.clock",
                    color: .orange,
                    stats: monthlyStats,
                    showMissing: true
                )
                .cardAppear(index: 2, animate: animateCards, reduceMotion: reduceMotion)

                statsCard(
                    title: "stats.currentWeek".localized,
                    icon: "briefcase.fill",
                    color: .green,
                    stats: weeklyStats,
                    showMissing: true
                )
                .cardAppear(index: 3, animate: animateCards, reduceMotion: reduceMotion)

                VacationSection(
                    stats: vacationStats,
                    isStartYear: isCurrentYearStartYear
                )
                .cardAppear(index: 4, animate: animateCards, reduceMotion: reduceMotion)
            }
            .padding(.horizontal)
            .padding(.top, DS.Spacing.sm)
            .padding(.bottom, DS.Spacing.xl)
            .dsGlassEffectGroup()
        }
        .dsScreenBackground(.blue)
        .quickAddOverlay()
        .navigationTitle("navigation.home".localized)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Analytics.shared.logScreenView("home")
            updateCurrentPeriod()
            loadStats()
            animateCards = true
        }
        .refreshable {
            updateCurrentPeriod()
            loadStats()
        }
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .id(StatsCache.shared.lastUpdate)
        }
        .onChange(of: StatsCache.shared.lastUpdate) { _, _ in
            loadStats()
        }
    }

    // MARK: - Hero & Cards

    /// Carte héro : le solde d'heures supplémentaires de l'année, la donnée
    /// la plus consultée, en très grand.
    private var heroCard: some View {
        let isPositive = yearlyStats.overtimeSeconds >= 0
        let balanceColor = isPositive ? DS.Colors.positive : DS.Colors.negative

        return VStack(spacing: DS.Spacing.xs) {
            Text(isPositive
                 ? "stats.overtimeHours".localized
                 : "stats.missingHours".localized)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(WorkTimeCalculations.formattedSecondsRounded(yearlyStats.overtimeSeconds))
                .font(.system(size: DS.Font.statDisplay, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(balanceColor)
                .contentTransition(.numericText(countsDown: !isPositive))

            Text("stats.year".localized(selectedYear))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .padding(.horizontal)
        .dsGlassSurface(cornerRadius: DS.Radius.large, tint: balanceColor)
        .accessibilityElement(children: .combine)
    }

    private func statsCard(
        title: String,
        icon: String,
        color: Color,
        stats: (totalHours: Double, overtimeSeconds: Int),
        showMissing: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            SectionHeader(title: title, icon: icon, color: color)
            StatsRow(stats: stats, showMissing: showMissing)
                .equatable()
        }
        .padding()
        .dsGlassSurface(cornerRadius: DS.Radius.card)
    }

    // MARK: - Stats Loading

    private func loadStats() {
        let calendar = Calendar.current

        let startOfYear = calendar.date(from: DateComponents(year: selectedYear))!
        let endOfYear = calendar.date(byAdding: DateComponents(year: 1), to: startOfYear)!
        let startOfMonth = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth)!
        let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeek)
        let startOfWeek = calendar.date(from: weekComponents)!
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
        let fetchStart = min(startOfYear, startOfMonth, startOfWeek)
        let fetchEnd = max(endOfYear, endOfMonth, endOfWeek)
        let days = fetchWorkDays(from: fetchStart, to: fetchEnd)
        let newYearlyStats = WorkTimeCalculations.activePeriodStats(from: days, startDate: startOfYear, endDate: endOfYear)
        let newMonthlyStats = WorkTimeCalculations.activePeriodStats(from: days, startDate: startOfMonth, endDate: endOfMonth)
        let newWeeklyStats = WorkTimeCalculations.activePeriodStats(from: days, startDate: startOfWeek, endDate: endOfWeek)

        withAnimation(DS.Animation.navigation) {
            yearlyStats = newYearlyStats
            monthlyStats = newMonthlyStats
            weeklyStats = newWeeklyStats
        }

        updateVacationStats()
    }

    private func fetchWorkDays(from startDate: Date, to endDate: Date) -> [WorkDay] {
        let predicate = #Predicate<WorkDay> {
            $0.date >= startDate &&
            $0.date < endDate &&
            !$0.isDeleted
        }
        var descriptor = FetchDescriptor<WorkDay>(predicate: predicate)
        descriptor.propertiesToFetch = [
            \.date, \.typeRawValue, \.totalHours,
            \.overtimeSeconds, \.isDeleted
        ]
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func updateVacationStats() {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let startYear = calendar.component(.year, from: settings.vacationStartDate)
        let entitlement = Double(settings.annualVacationDays)
        let stats = VacationCalculations.remainingStats(for: currentYear, workDays: vacationWorkDays, annualEntitlement: entitlement)
        let annualForDisplay = (currentYear == startYear) ? 0 : entitlement
        vacationStats = (used: stats.used, remaining: stats.remaining, carryIn: stats.carryIn, annual: annualForDisplay)
        isCurrentYearStartYear = (currentYear == startYear)
    }

    // MARK: - Helper Methods

    private func updateCurrentPeriod() {
        let currentDate = Date()
        let calendar = Calendar.current
        selectedYear = calendar.component(.year, from: currentDate)
        selectedMonth = calendar.component(.month, from: currentDate)
        selectedWeek = currentDate
    }
}

// MARK: - Section Header (style Apple Settings)

private struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: DS.IconSize.sectionHeader, height: DS.IconSize.sectionHeader)
                .background(color, in: RoundedRectangle(cornerRadius: DS.IconRadius.sectionHeader))

            Text(title)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(nil)
        }
        .padding(.bottom, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Stats Row

private struct StatsRow: View, Equatable {
    let stats: (totalHours: Double, overtimeSeconds: Int)
    let showMissing: Bool

    static func == (lhs: StatsRow, rhs: StatsRow) -> Bool {
        lhs.stats.totalHours == rhs.stats.totalHours &&
        lhs.stats.overtimeSeconds == rhs.stats.overtimeSeconds &&
        lhs.showMissing == rhs.showMissing
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("stats.workedHours".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(WorkTimeCalculations.formattedHoursRounded(stats.totalHours))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(stats.overtimeSeconds >= 0
                     ? "stats.overtimeHours".localized
                     : "stats.missingHours".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(WorkTimeCalculations.formattedSecondsRounded(stats.overtimeSeconds))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(stats.overtimeSeconds >= 0 ? Color.green : Color.red)
                    .contentTransition(.numericText(countsDown: stats.overtimeSeconds < 0))
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Vacation Section

private struct VacationSection: View {
    let stats: (used: Double, remaining: Double, carryIn: Double, annual: Double)
    let isStartYear: Bool

    @State private var showVacationsView = false

    private var usageProgress: Double {
        let total = stats.annual + stats.carryIn
        return total > 0 ? min(1.0, stats.used / total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            SectionHeader(
                title: "navigation.vacations".localized,
                icon: "sun.max.fill",
                color: .orange
            )

            // Barre de progression
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ProgressView(value: usageProgress)
                    .tint(.orange)
                    .animation(DS.Animation.progress, value: usageProgress)

                HStack {
                    Text(String(format: "vacation.daysUsed".localized, stats.used))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "vacation.daysOfTotal".localized, stats.used, stats.annual + stats.carryIn))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Équivalent en heures
            HStack {
                Text("home.vacation.balanceHours".localized)
                    .font(.subheadline)
                Spacer()
                Text(formatDaysAsHours(stats.remaining))
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(stats.remaining > 0 ? .green : .red)
            }

            // Stats détaillées
            if isStartYear {
                statRow("vacation.initialBalance".localized, value: stats.carryIn, color: .purple)
            } else {
                statRow("vacation.annualEntitlement".localized, value: stats.annual, color: .blue)
                statRow("vacation.carryIn".localized, value: stats.carryIn, color: .purple)
            }
            statRow("vacation.used".localized, value: stats.used, color: .orange)
            statRow("vacation.remaining".localized,
                    value: stats.remaining,
                    color: stats.remaining > 0 ? .green : .red,
                    bold: true)

            Divider()

            // Bouton détails
            Button {
                showVacationsView = true
            } label: {
                HStack {
                    Text("action.viewDetails".localized)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .dsGlassSurface(cornerRadius: DS.Radius.card, tint: .orange)
        .sheet(isPresented: $showVacationsView) {
            VacationsView()
        }
    }

    private func statRow(_ title: String, value: Double, color: Color, bold: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text("\(formatDaysValue(value))  (\(formatDaysAsHours(value)))")
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(bold ? .semibold : .regular)
                .foregroundStyle(color)
        }
    }

    private func formatDaysValue(_ days: Double) -> String {
        String(format: "%.1f %@", days, "time.days.short".localized)
    }

    /// Convertit un nombre de jours en heures formatées
    private func formatDaysAsHours(_ days: Double) -> String {
        let hours = days * UserSettings.shared.standardDailyHours
        if UserSettings.shared.useDecimalHours {
            return String(format: "%.1f%@", hours, "time.hours.short".localized)
        } else {
            let totalMinutes = Int(round(hours * 60))
            let h = abs(totalMinutes / 60)
            let m = abs(totalMinutes % 60)
            let sign = hours < 0 ? "-" : ""
            return String(format: "%@%d%@%02d", sign, h, "time.hours.short".localized, m)
        }
    }
}

// MARK: - CardView (content layer)

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .dsGlassSurface(cornerRadius: DS.Radius.card)
    }
}

// MARK: - Shared Components

struct StatsComponent: View {
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(valueColor)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

struct VacationStatsComponent: View {
    let title: String
    let value: Double
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f %@", value, "time.days.short".localized))
                .font(.system(.title3, design: .rounded))
                .foregroundStyle(valueColor)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(format: "accessibility.days".localized, title, String(format: "%.1f", value)))
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        HomeTabView()
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}
