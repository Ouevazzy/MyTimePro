//
//  ChartsView.swift
//  WorkTimer
//
//  Graphiques de visualisation des heures de travail.
//  Coordinateur : récupère les WorkDay, délègue le calcul à ChartsDataService
//  et le rendu aux sous-vues de ChartsSubviews.
//

import SwiftUI
import SwiftData

private struct ChartsLoadIdentity: Hashable {
    let year: Int
    let revision: Int
}

// MARK: - Charts View

struct ChartsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedChartType: ChartType = .daily
    @State private var dataRevision = 0
    @State private var animateCharts = false
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 250
    @State private var cachedWeeklyData: [WeeklyHoursData] = []
    @State private var cachedMonthlyData: [MonthlyHoursData] = []
    @State private var cachedDailyData: [DailyHoursData] = []
    @State private var cachedDistributionData: [WorkTypeDistribution] = []
    @State private var cachedSummary: ChartSummary = .empty
    @State private var availableYears: [Int] = [Calendar.current.component(.year, from: Date())]

    enum ChartType: String, CaseIterable, Hashable {
        case daily
        case weekly
        case monthly
        case distribution

        var title: String {
            switch self {
            case .daily: return "charts.type.daily".localized
            case .weekly: return "charts.type.weekly".localized
            case .monthly: return "charts.type.monthly".localized
            case .distribution: return "charts.type.distribution".localized
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sélecteur d'année et type
                headerSection

                // Graphique principal
                switch selectedChartType {
                case .weekly:
                    WeeklyChartView(
                        data: cachedWeeklyData,
                        chartHeight: chartHeight,
                        animate: animateCharts,
                        reduceMotion: reduceMotion
                    )
                case .monthly:
                    MonthlyChartView(
                        data: cachedMonthlyData,
                        selectedYear: selectedYear,
                        chartHeight: chartHeight,
                        animate: animateCharts,
                        reduceMotion: reduceMotion
                    )
                case .daily:
                    DailyChartView(
                        data: cachedDailyData,
                        chartHeight: chartHeight,
                        animate: animateCharts,
                        reduceMotion: reduceMotion
                    )
                case .distribution:
                    DistributionChartView(
                        data: cachedDistributionData,
                        chartHeight: chartHeight,
                        animate: animateCharts,
                        reduceMotion: reduceMotion
                    )
                }

                // Résumé statistique
                ChartsSummaryView(summary: cachedSummary, selectedYear: selectedYear)
            }
            .dsGlassEffectGroup()
            .padding()
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
        .refreshable {
            dataRevision += 1
        }
        .navigationTitle("charts.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: selectedChartType)
        .task(id: ChartsLoadIdentity(year: selectedYear, revision: dataRevision)) {
            loadChartData()
        }
        .onChange(of: selectedChartType) { _, _ in
            restartChartAnimation()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Sélecteur de type de graphique
            Picker("Type", selection: $selectedChartType) {
                ForEach(ChartType.allCases, id: \.self) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Sélecteur d'année
            HStack {
                Text("charts.year".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Picker("charts.year".localized, selection: $selectedYear) {
                    ForEach(availableYears, id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)
        }
        .padding(DS.Spacing.md)
        .dsGlassSurface(cornerRadius: DS.Radius.card)
    }

    // MARK: - Data Loading

    private func loadChartData() {
        let calendar = Calendar.current
        let years = fetchAvailableYears()
        availableYears = Array(Set(years + [selectedYear])).sorted(by: >)

        guard let yearStart = calendar.date(from: DateComponents(year: selectedYear)),
              let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart),
              let dailyStart = calendar.date(byAdding: .day, value: -30, to: Date()),
              let dailyEnd = calendar.date(byAdding: .day, value: 1, to: Date())
        else { return }

        let yearWorkDays = fetchWorkDays(from: yearStart, to: yearEnd, order: .forward)
        let dailyWorkDays = fetchWorkDays(from: dailyStart, to: dailyEnd, order: .forward)

        cachedWeeklyData = ChartsDataService.weeklyData(from: yearWorkDays)
        cachedMonthlyData = ChartsDataService.monthlyData(from: yearWorkDays)
        cachedDailyData = ChartsDataService.dailyData(from: dailyWorkDays)
        cachedDistributionData = ChartsDataService.distributionData(from: yearWorkDays)
        cachedSummary = ChartsDataService.summary(from: yearWorkDays)
        restartChartAnimation()
    }

    private func fetchAvailableYears() -> [Int] {
        var descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate<WorkDay> { !$0.isDeleted },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.propertiesToFetch = [\.date, \.isDeleted]

        do {
            let days = try modelContext.fetch(descriptor)
            let years = Set(days.map { Calendar.current.component(.year, from: $0.date) })
            return years.sorted(by: >)
        } catch {
            AppLogger.error("Chart years fetch failed", category: AppLogger.data, error: error)
            return [selectedYear]
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
            AppLogger.error("Chart work days fetch failed", category: AppLogger.data, error: error)
            return []
        }
    }

    private func restartChartAnimation() {
        guard !reduceMotion else {
            animateCharts = true
            return
        }

        animateCharts = false
        DispatchQueue.main.async {
            withAnimation(DS.Animation.appear) {
                animateCharts = true
            }
        }
    }
}

// MARK: - WorkDayType Extension

extension WorkDayType {
    var displayName: String {
        localizedName
    }
}

#Preview {
    NavigationStack {
        ChartsView()
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}
