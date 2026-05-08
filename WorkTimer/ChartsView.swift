//
//  ChartsView.swift
//  WorkTimer
//
//  Graphiques de visualisation des heures de travail
//

import SwiftUI
import Charts
import SwiftData

// MARK: - Data Models for Charts

struct WeeklyHoursData: Identifiable {
    let id = UUID()
    let weekNumber: Int
    let weekLabel: String
    let totalHours: Double
    let overtime: Double
    let standardHours: Double
}

struct MonthlyHoursData: Identifiable {
    let id = UUID()
    let month: Int
    let monthName: String
    let totalHours: Double
    let overtime: Double
    let workDays: Int
}

struct DailyHoursData: Identifiable {
    let id = UUID()
    let date: Date
    let dayName: String
    let hours: Double
    let type: WorkDayType
}

struct WorkTypeDistribution: Identifiable {
    let id = UUID()
    let type: WorkDayType
    let count: Int
    let percentage: Double
}

// MARK: - Charts View

struct ChartsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedChartType: ChartType = .daily
    @State private var animateCharts = false
    @ScaledMetric(relativeTo: .body) private var chartHeight: CGFloat = 250
    @State private var cachedWeeklyData: [WeeklyHoursData] = []
    @State private var cachedMonthlyData: [MonthlyHoursData] = []
    @State private var cachedDailyData: [DailyHoursData] = []
    
    enum ChartType: String, CaseIterable {
        case daily = "Jours"
        case weekly = "Semaines"
        case monthly = "Mois"
        case distribution = "Répartition"
    }
    
    private var availableYears: [Int] {
        let years = Set(workDays.map { Calendar.current.component(.year, from: $0.date) })
        return years.sorted(by: >)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sélecteur d'année et type
                headerSection

                // Graphique principal
                switch selectedChartType {
                case .weekly:
                    weeklyChart
                case .monthly:
                    monthlyChart
                case .daily:
                    dailyChart
                case .distribution:
                    distributionChart
                }

                // Résumé statistique
                summarySection
            }
            .padding()
        }
        .refreshable {
            refreshChartData()
        }
        .navigationTitle("charts.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshChartData()
            withAnimation(DS.Animation.appear) {
                animateCharts = true
            }
        }
        .onChange(of: selectedYear) { _, _ in
            refreshChartData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Sélecteur de type de graphique
            Picker("Type", selection: $selectedChartType) {
                ForEach(ChartType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            // Sélecteur d'année
            if !availableYears.isEmpty {
                HStack {
                    Text("charts.year".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Picker("Année", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Weekly Chart
    
    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("charts.weeklyHours".localized)
                .font(.headline)

            let data = cachedWeeklyData
            
            if data.isEmpty {
                emptyChartView
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Semaine", item.weekLabel),
                        y: .value("Heures", animateCharts ? item.totalHours : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                    
                    // Ligne de référence pour les heures standard
                    RuleMark(y: .value("Standard", item.standardHours))
                        .foregroundStyle(.orange.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .frame(height: chartHeight)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Graphique des heures par semaine, \(data.count) semaines affichées")
                .animation(DS.Animation.progress, value: animateCharts)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5)
        )
    }

    // MARK: - Monthly Chart
    
    private var monthlyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("charts.monthlyHours".localized)
                .font(.headline)

            let data = cachedMonthlyData
            
            if data.isEmpty {
                emptyChartView
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Mois", item.monthName),
                        y: .value("Heures", animateCharts ? item.totalHours : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(4)
                    
                    // Overtime en superposition
                    if item.overtime > 0 {
                        BarMark(
                            x: .value("Mois", item.monthName),
                            y: .value("Overtime", animateCharts ? item.overtime : 0)
                        )
                        .foregroundStyle(.green.opacity(0.7))
                        .cornerRadius(4)
                    } else if item.overtime < 0 {
                        BarMark(
                            x: .value("Mois", item.monthName),
                            y: .value("Déficit", animateCharts ? abs(item.overtime) : 0)
                        )
                        .foregroundStyle(.red.opacity(0.7))
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: chartHeight)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Graphique des heures par mois pour l'année \(selectedYear)")
                .animation(DS.Animation.progress, value: animateCharts)

                // Légende
                HStack(spacing: 20) {
                    legendItem(color: .purple, text: "Total")
                    legendItem(color: .green, text: "Surplus")
                    legendItem(color: .red, text: "Déficit")
                }
                .font(.caption)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5)
        )
    }
    
    // MARK: - Daily Chart (Last 30 days)
    
    private var dailyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("charts.last30Days".localized)
                .font(.headline)

            let data = cachedDailyData
            
            if data.isEmpty {
                emptyChartView
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Jour", item.date, unit: .day),
                        y: .value("Heures", animateCharts ? item.hours : 0)
                    )
                    .foregroundStyle(by: .value("Type", item.type.rawValue))
                    .cornerRadius(2)
                }
                .chartForegroundStyleScale([
                    WorkDayType.work.rawValue: Color.blue,
                    WorkDayType.vacation.rawValue: Color.green,
                    WorkDayType.halfDayVacation.rawValue: Color.mint,
                    WorkDayType.sickLeave.rawValue: Color.orange,
                    WorkDayType.holiday.rawValue: Color.purple,
                    WorkDayType.compensatory.rawValue: Color.pink,
                    WorkDayType.training.rawValue: Color.cyan
                ])
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.caption2)
                    }
                }
                .frame(height: chartHeight)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Graphique des 30 derniers jours, \(data.count) jours affichés")
                .animation(DS.Animation.progress, value: animateCharts)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5)
        )
    }

    // MARK: - Distribution Chart
    
    private var distributionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("charts.distribution".localized)
                .font(.headline)
            
            let data = distributionData
            
            if data.isEmpty {
                emptyChartView
            } else {
                Chart(data) { item in
                    SectorMark(
                        angle: .value("Count", animateCharts ? item.count : 0),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Type", item.type.displayName))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale([
                    WorkDayType.work.displayName: Color.blue,
                    WorkDayType.vacation.displayName: Color.green,
                    WorkDayType.halfDayVacation.displayName: Color.mint,
                    WorkDayType.sickLeave.displayName: Color.orange,
                    WorkDayType.holiday.displayName: Color.purple,
                    WorkDayType.compensatory.displayName: Color.pink,
                    WorkDayType.training.displayName: Color.cyan
                ])
                .frame(height: chartHeight)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Graphique de répartition des types de journées")
                .animation(DS.Animation.progress, value: animateCharts)

                // Détails
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(data) { item in
                        HStack {
                            Circle()
                                .fill(colorForType(item.type))
                                .frame(width: 10, height: 10)
                            Text(item.type.displayName)
                                .font(.caption)
                            Spacer()
                            Text("\(item.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5)
        )
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        let yearWorkDays = workDays.filter {
            Calendar.current.component(.year, from: $0.date) == selectedYear
        }
        
        let totalHours = yearWorkDays.filter { $0.type == .work }.reduce(0.0) { $0 + $1.totalHours }
        let totalOvertime = yearWorkDays.reduce(0) { $0 + $1.overtimeSeconds }
        let workDaysCount = yearWorkDays.filter { $0.type == .work }.count
        let avgHours = workDaysCount > 0 ? totalHours / Double(workDaysCount) : 0
        
        return VStack(spacing: 16) {
            Text(String(format: "charts.summary".localized, selectedYear))
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                summaryCard(
                    title: "Total heures",
                    value: String(format: "%.1fh", totalHours),
                    icon: "clock.fill",
                    color: .blue
                )
                
                summaryCard(
                    title: "Overtime",
                    value: formatOvertime(totalOvertime),
                    icon: totalOvertime >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                    color: totalOvertime >= 0 ? .green : .red
                )
                
                summaryCard(
                    title: "Jours travaillés",
                    value: "\(workDaysCount)",
                    icon: "calendar.badge.checkmark",
                    color: .purple
                )
                
                summaryCard(
                    title: "Moyenne/jour",
                    value: String(format: "%.1fh", avgHours),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 5)
        )
    }
    
    // MARK: - Helper Views
    
    private var emptyChartView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("charts.noData".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
    
    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
    
    // MARK: - Data Processing

    private func refreshChartData() {
        cachedWeeklyData = computeWeeklyData()
        cachedMonthlyData = computeMonthlyData()
        cachedDailyData = computeDailyData()
    }

    private func computeWeeklyData() -> [WeeklyHoursData] {
        let calendar = Calendar.current
        let settings = UserSettings.shared
        let standardWeeklyHours = settings.weeklyHours
        
        let yearWorkDays = workDays.filter {
            calendar.component(.year, from: $0.date) == selectedYear &&
            $0.type == .work
        }

        var weeklyDict: [Int: (hours: Double, overtime: Int)] = [:]
        
        for day in yearWorkDays {
            let week = calendar.component(.weekOfYear, from: day.date)
            let current = weeklyDict[week] ?? (0, 0)
            weeklyDict[week] = (current.hours + day.totalHours, current.overtime + day.overtimeSeconds)
        }
        
        return weeklyDict.keys.sorted().suffix(12).map { week in
            let data = weeklyDict[week]!
            return WeeklyHoursData(
                weekNumber: week,
                weekLabel: "S\(week)",
                totalHours: data.hours,
                overtime: Double(data.overtime) / 3600.0,
                standardHours: standardWeeklyHours
            )
        }
    }
    
    private func computeMonthlyData() -> [MonthlyHoursData] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        
        let yearWorkDays = workDays.filter {
            calendar.component(.year, from: $0.date) == selectedYear &&
            $0.type == .work
        }

        var monthlyDict: [Int: (hours: Double, overtime: Int, days: Int)] = [:]
        
        for day in yearWorkDays {
            let month = calendar.component(.month, from: day.date)
            let current = monthlyDict[month] ?? (0, 0, 0)
            monthlyDict[month] = (current.hours + day.totalHours, current.overtime + day.overtimeSeconds, current.days + 1)
        }
        
        return (1...12).compactMap { month -> MonthlyHoursData? in
            let data = monthlyDict[month] ?? (0, 0, 0)
            var components = DateComponents()
            components.month = month
            let date = calendar.date(from: components) ?? Date()
            formatter.dateFormat = "MMM"
            
            return MonthlyHoursData(
                month: month,
                monthName: formatter.string(from: date).capitalized,
                totalHours: data.hours,
                overtime: Double(data.overtime) / 3600.0,
                workDays: data.days
            )
        }
    }
    
    private func computeDailyData() -> [DailyHoursData] {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "E"
        
        return workDays
            .filter { $0.date >= thirtyDaysAgo }
            .sorted { $0.date < $1.date }
            .map { day in
                DailyHoursData(
                    date: day.date,
                    dayName: formatter.string(from: day.date),
                    hours: day.totalHours,
                    type: day.type
                )
            }
    }
    
    private var distributionData: [WorkTypeDistribution] {
        let calendar = Calendar.current
        let yearWorkDays = workDays.filter {
            calendar.component(.year, from: $0.date) == selectedYear
        }
        
        let total = yearWorkDays.count
        guard total > 0 else { return [] }
        
        var typeCount: [WorkDayType: Int] = [:]
        for day in yearWorkDays {
            typeCount[day.type, default: 0] += 1
        }
        
        return typeCount.map { type, count in
            WorkTypeDistribution(
                type: type,
                count: count,
                percentage: Double(count) / Double(total) * 100
            )
        }.sorted { $0.count > $1.count }
    }
    
    // MARK: - Helpers
    
    private func formatOvertime(_ seconds: Int) -> String {
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        let sign = seconds < 0 ? "-" : "+"
        return String(format: "%@%dh%02d", sign, hours, minutes)
    }
    
    private func colorForType(_ type: WorkDayType) -> Color {
        switch type {
        case .work: return .accentColor
        case .vacation: return .green
        case .halfDayVacation: return .mint
        case .sickLeave: return .orange
        case .holiday: return .purple
        case .compensatory: return .pink
        case .training: return .teal
        }
    }
}

// MARK: - WorkDayType Extension

extension WorkDayType {
    var displayName: String {
        switch self {
        case .work: return "Travail"
        case .vacation: return "Congé"
        case .halfDayVacation: return "Demi-congé"
        case .sickLeave: return "Maladie"
        case .holiday: return "Férié"
        case .compensatory: return "Récup"
        case .training: return "Formation"
        }
    }
}

#Preview {
    NavigationStack {
        ChartsView()
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}

