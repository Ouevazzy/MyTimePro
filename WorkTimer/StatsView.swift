import SwiftUI
import SwiftData

private struct StatsLoadIdentity: Hashable {
    let year: Int
    let revision: Int
}

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 150), spacing: DS.Spacing.md)]
    }

    var body: some View {
        VStack(spacing: 0) {
            yearSelector
                .padding(.horizontal)
                .padding(.vertical, DS.Spacing.sm)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    annualSummary

                    if activeMonthlyStats.isEmpty {
                        EmptyStateView(
                            icon: "chart.bar.xaxis",
                            title: String(format: "stats.noData".localized, selectedYear),
                            subtitle: "stats.noDataHelp".localized,
                            iconColors: [.blue, .cyan]
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.xl)
                    }

                    ForEach(activeMonthlyStats) { monthStat in
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            HStack {
                                Text(monthStat.monthName)
                                    .font(.headline)
                                Spacer()
                                if monthStat.workDays > 0 {
                                    Text(formatWholeDays(monthStat.workDays))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityAddTraits(.isHeader)

                            MonthStatContent(
                                monthStat: monthStat,
                                formattedHours: WorkTimeCalculations.formattedHoursRounded(monthStat.totalHours),
                                formattedOvertime: WorkTimeCalculations.formattedSecondsRounded(monthStat.overtimeSeconds),
                                formattedVacation: formatVacationWithHours(monthStat.vacationDays),
                                formattedSickDays: formatWholeDays(monthStat.sickDays),
                                formattedBonus: settings.formatCurrency(monthStat.totalBonus),
                                formattedEarnings: settings.isHourlyRateEnabled
                                    ? settings.formatCurrency(monthStat.totalHours * settings.hourlyRate + monthStat.totalBonus)
                                    : nil,
                                overtimeSeconds: monthStat.overtimeSeconds
                            )
                            .equatable()
                            .padding(DS.Spacing.lg)
                            .dsContentSurface()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.xl)
            }
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

    private var annualSummary: some View {
        VStack(spacing: DS.Spacing.md) {
            LazyVGrid(columns: summaryColumns, spacing: DS.Spacing.md) {
                StatCard(
                    icon: "clock",
                    iconColor: .blue,
                    value: WorkTimeCalculations.formattedHoursRounded(yearlyStats.totalHours),
                    title: "stats.totalHours".localized
                )
                .equatable()
                .padding(DS.Spacing.lg)
                .dsContentSurface()

                StatCard(
                    icon: yearlyStats.overtimeSeconds == 0 ? "equal.circle" : yearlyStats.overtimeSeconds > 0 ? "arrow.up.circle" : "arrow.down.circle",
                    iconColor: DS.Colors.balance(Double(yearlyStats.overtimeSeconds)),
                    value: WorkTimeCalculations.formattedSecondsRounded(yearlyStats.overtimeSeconds),
                    title: yearlyStats.overtimeSeconds < 0 ? "stats.missingHours".localized : "stats.overtimeHours".localized,
                    valueColor: DS.Colors.balance(Double(yearlyStats.overtimeSeconds))
                )
                .equatable()
                .padding(DS.Spacing.lg)
                .dsContentSurface()
            }

            VStack(spacing: DS.Spacing.md) {
                StatSummaryRow(icon: "briefcase", title: "stats.workDays".localized, value: formatWholeDays(yearlyStats.workDays))
                Divider()
                StatSummaryRow(icon: "umbrella", title: "stats.vacationDays".localized, value: formatDaysValue(yearlyStats.vacationDays), subtitle: formatDaysAsHours(yearlyStats.vacationDays))
                Divider()
                StatSummaryRow(icon: "cross", title: "stats.sickDays".localized, value: formatWholeDays(yearlyStats.sickDays))
                Divider()
                StatSummaryRow(icon: "banknote", title: "stats.bonus".localized, value: settings.formatCurrency(yearlyStats.totalBonus))
                if settings.isHourlyRateEnabled {
                    Divider()
                    StatSummaryRow(
                        icon: "eurosign.circle",
                        title: "stats.earnings".localized,
                        value: settings.formatCurrency(yearlyStats.totalHours * settings.hourlyRate + yearlyStats.totalBonus)
                    )
                }
            }
            .padding(DS.Spacing.lg)
            .dsContentSurface()
        }
    }

    private var yearSelector: some View {
        HStack(spacing: DS.Spacing.md) {
            Button {
                guard selectedYear > 2000 else { return }
                withAnimation(reduceMotion ? nil : DS.Animation.navigation) { selectedYear -= 1 }
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
                withAnimation(reduceMotion ? nil : DS.Animation.navigation) { selectedYear += 1 }
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

        withAnimation(reduceMotion ? nil : DS.Animation.appear) {
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

#if DEBUG
#Preview("Données d'exemple") {
    NavigationStack {
        StatsView()
            .modelContainer(try! DisplayPreviewData.makeContainer())
    }
    .transaction { transaction in
        transaction.animation = nil
        transaction.disablesAnimations = true
    }
}
#endif
