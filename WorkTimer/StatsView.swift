import SwiftUI
import SwiftData

private struct StatsLoadIdentity: Hashable {
    let year: Int
    let revision: Int
}

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedYear: Int
    @State private var statsRevision = 0
    let settings = UserSettings.shared

    init() {
        let currentYear = Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: currentYear)
    }

    @State private var yearlyStats: YearStats = .empty
    @State private var monthlyStats: [MonthStats] = []

    private var activeMonthlyStats: [MonthStats] {
        monthlyStats.filter(\.hasActivity)
    }

    private var summaryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 104), spacing: DS.Spacing.sm)]
    }

    var body: some View {
        VStack(spacing: 0) {
            yearSelector
                .padding(.horizontal)
                .padding(.top, DS.Spacing.sm)

            // Grille des statistiques annuelles
            LazyVGrid(columns: summaryColumns, spacing: DS.Spacing.sm) {
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
                    value: formatDaysValue(yearlyStats.vacationDays),
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
            .padding(DS.Spacing.md)
            .dsGlassSurface(cornerRadius: DS.Radius.card)
            .padding(.horizontal)
            .padding(.vertical, DS.Spacing.sm)

            // Liste des mois
            List {
                if activeMonthlyStats.isEmpty {
                    Section {
                        EmptyStateView(
                            icon: "chart.bar.xaxis",
                            title: String(format: "stats.noData".localized, selectedYear),
                            subtitle: "stats.noDataHelp".localized,
                            iconColors: [.blue, .cyan]
                        )
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                ForEach(activeMonthlyStats) { monthStat in
                    Section {
                        MonthStatContent(
                            monthStat: monthStat,
                            formattedHours: WorkTimeCalculations.formattedHoursRounded(monthStat.totalHours),
                            formattedOvertime: WorkTimeCalculations.formattedSecondsRounded(monthStat.overtimeSeconds),
                            formattedVacation: formatVacationWithHours(monthStat.vacationDays),
                            formattedSickDays: formatWholeDays(monthStat.sickDays),
                            formattedBonus: String(format: "%.2f CHF", monthStat.totalBonus),
                            isOvertimePositive: monthStat.overtimeSeconds >= 0
                        )
                        .equatable()
                        .padding(DS.Spacing.md)
                        .dsGlassSurface(cornerRadius: DS.Radius.card)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    } header: {
                        HStack {
                            Text(monthStat.monthName)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            Spacer()
                            if monthStat.workDays > 0 {
                                Text(formatWholeDays(monthStat.workDays))
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
            .scrollContentBackground(.hidden)
            .refreshable {
                StatsCache.shared.invalidateYear(selectedYear)
                statsRevision += 1
            }
        }
        .dsScreenBackground(.blue)
        .navigationTitle("navigation.stats".localized)
        .navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .sensoryFeedback(.selection, trigger: selectedYear)
        .task(id: StatsLoadIdentity(year: selectedYear, revision: statsRevision)) {
            loadStats(for: selectedYear)
        }
    }

    private var yearSelector: some View {
        HStack(spacing: DS.Spacing.md) {
            Button {
                guard selectedYear > 2000 else { return }
                withAnimation(DS.Animation.navigation) { selectedYear -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .disabled(selectedYear <= 2000)
            .accessibilityLabel("accessibility.previousYear".localized)
            .accessibilityHint(String(format: "accessibility.yearStats".localized, selectedYear - 1))

            Spacer()

            Text(verbatim: "\(selectedYear)")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .contentTransition(.numericText())
                .accessibilityLabel(String(format: "accessibility.yearStats".localized, selectedYear))

            Spacer()

            Button {
                guard selectedYear < 2100 else { return }
                withAnimation(DS.Animation.navigation) { selectedYear += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .fontWeight(.semibold)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .disabled(selectedYear >= 2100)
            .accessibilityLabel("accessibility.nextYear".localized)
            .accessibilityHint(String(format: "accessibility.yearStats".localized, selectedYear + 1))
        }
    }

    // MARK: - Formatting

    private func formatDaysValue(_ days: Double) -> String {
        String(format: "%.1f %@", days, "time.days.short".localized)
    }

    private func formatVacationWithHours(_ days: Double) -> String {
        "\(formatDaysValue(days)) (\(formatDaysAsHours(days)))"
    }

    private func formatWholeDays(_ days: Int) -> String {
        let unit = days == 1 ? "time.day".localized : "time.days".localized
        return "\(days) \(unit)"
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
            return String(format: "%@%d%@%02d", sign, h, "time.hours.short".localized, m)
        }
    }

    // MARK: - Calculations

    private func loadStats(for year: Int) {
        let calculated = StatsCalculationService.stats(for: year) { start, end in
            fetchWorkDays(from: start, to: end, order: .forward)
        }

        withAnimation(DS.Animation.appear) {
            yearlyStats = calculated.year
            monthlyStats = calculated.months
        }
    }

    private func fetchWorkDays(from startDate: Date, to endDate: Date, order: SortOrder) -> [WorkDay] {
        var descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate<WorkDay> {
                $0.date >= startDate && $0.date < endDate && !$0.isDeleted
            },
            sortBy: [SortDescriptor(\.date, order: order)]
        )
        descriptor.propertiesToFetch = [
            \.id, \.date, \.typeRawValue, \.totalHours,
            \.overtimeSeconds, \.bonusAmount, \.isDeleted
        ]

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            AppLogger.error("Stats fetch failed", category: AppLogger.data, error: error)
            return []
        }
    }
}

#Preview {
    NavigationStack {
        StatsView()
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}
