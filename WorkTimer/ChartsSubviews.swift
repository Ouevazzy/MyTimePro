//
//  ChartsSubviews.swift
//  WorkTimer
//
//  Sous-vues de graphiques extraites de ChartsView pour alléger le coordinateur.
//  Chaque vue reçoit ses données déjà calculées par ChartsDataService.
//

import SwiftUI
import Charts

// MARK: - Shared Palette

enum ChartPalette {
    /// Couleur de référence d'un type d'activité (légendes et pastilles de détail).
    static func color(for type: WorkDayType) -> Color {
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

// MARK: - Empty State

struct EmptyChartView: View {
    var body: some View {
        ContentUnavailableView {
            Label("charts.noData".localized, systemImage: "chart.bar.xaxis")
        } description: {
            Text("charts.noDataHelp".localized)
        }
        .symbolRenderingMode(.hierarchical)
        .tint(.secondary)
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Weekly Chart

struct WeeklyChartView: View {
    let data: [WeeklyHoursData]
    let chartHeight: CGFloat
    let animate: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("charts.weeklyHours".localized)
                .font(.headline)

            if data.isEmpty {
                EmptyChartView()
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("charts.axis.week".localized, item.weekLabel),
                        y: .value("charts.axis.hours".localized, animate ? item.totalHours : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .bottom, endPoint: .top)
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
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .frame(height: chartHeight)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("charts.accessibility.weekly".localized(data.count))
                .animation(reduceMotion ? nil : DS.Animation.progress, value: animate)
            }
        }
        .padding()
        .dsGlassSurface(cornerRadius: DS.Radius.card)
    }
}

// MARK: - Monthly Chart

struct MonthlyChartView: View {
    let data: [MonthlyHoursData]
    let selectedYear: Int
    let chartHeight: CGFloat
    let animate: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("charts.monthlyHours".localized)
                .font(.headline)

            if data.isEmpty {
                EmptyChartView()
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("charts.axis.month".localized, item.monthName),
                        y: .value("charts.axis.hours".localized, animate ? item.totalHours : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .pink], startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(4)

                    // Overtime / déficit en superposition.
                    // BarMark toujours émis (hauteur nulle si overtime == 0) pour éviter
                    // un _ConditionalContent dont la conformité à ChartContent exige iOS 27+.
                    BarMark(
                        x: .value("charts.axis.month".localized, item.monthName),
                        y: .value("charts.axis.overtime".localized, animate ? abs(item.overtime) : 0)
                    )
                    .foregroundStyle((item.overtime >= 0 ? Color.green : Color.red).opacity(0.7))
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: chartHeight)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("charts.accessibility.monthly".localized(selectedYear))
                .animation(reduceMotion ? nil : DS.Animation.progress, value: animate)

                // Légende
                HStack(spacing: 20) {
                    legendItem(color: .purple, text: "charts.legend.total".localized)
                    legendItem(color: .green, text: "charts.legend.surplus".localized)
                    legendItem(color: .red, text: "charts.legend.deficit".localized)
                }
                .font(.caption)
            }
        }
        .padding()
        .dsGlassSurface(cornerRadius: DS.Radius.card)
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
}

// MARK: - Daily Chart (Last 30 days)

struct DailyChartView: View {
    let data: [DailyHoursData]
    let chartHeight: CGFloat
    let animate: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("charts.last30Days".localized)
                .font(.headline)

            if data.isEmpty {
                EmptyChartView()
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("charts.axis.day".localized, item.date, unit: .day),
                        y: .value("charts.axis.hours".localized, animate ? item.hours : 0)
                    )
                    .foregroundStyle(by: .value("Type", item.type.displayName))
                    .cornerRadius(2)
                }
                .chartForegroundStyleScale([
                    WorkDayType.work.displayName: Color.blue,
                    WorkDayType.vacation.displayName: Color.orange,
                    WorkDayType.halfDayVacation.displayName: Color.orange.opacity(0.75),
                    WorkDayType.sickLeave.displayName: Color.red,
                    WorkDayType.holiday.displayName: Color.yellow,
                    WorkDayType.compensatory.displayName: Color.green,
                    WorkDayType.training.displayName: Color.purple
                ])
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.caption2)
                    }
                }
                .frame(height: chartHeight)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("charts.accessibility.daily".localized(data.count))
                .animation(reduceMotion ? nil : DS.Animation.progress, value: animate)

                typeLegend(for: ChartsDataService.orderedTypes(in: data))
            }
        }
        .padding()
        .dsGlassSurface(cornerRadius: DS.Radius.card)
    }

    private func typeLegend(for types: [WorkDayType]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
            ForEach(types, id: \.self) { type in
                HStack(spacing: 6) {
                    Circle()
                        .fill(ChartPalette.color(for: type))
                        .frame(width: 8, height: 8)
                    Text(type.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Distribution Chart

struct DistributionChartView: View {
    let data: [WorkTypeDistribution]
    let chartHeight: CGFloat
    let animate: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("charts.distribution".localized)
                .font(.headline)

            if data.isEmpty {
                EmptyChartView()
            } else {
                Chart(data) { item in
                    SectorMark(
                        angle: .value("charts.axis.count".localized, animate ? item.count : 0),
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
                .chartLegend(.hidden)
                .frame(height: chartHeight)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("charts.accessibility.distribution".localized)
                .animation(reduceMotion ? nil : DS.Animation.progress, value: animate)

                // Détails
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(data) { item in
                        HStack {
                            Circle()
                                .fill(ChartPalette.color(for: item.type))
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
        .dsGlassSurface(cornerRadius: DS.Radius.card)
    }
}

// MARK: - Summary

struct ChartsSummaryView: View {
    let summary: ChartSummary
    let selectedYear: Int

    var body: some View {
        VStack(spacing: 16) {
            Text(String(format: "charts.summary".localized, selectedYear))
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                summaryCard(
                    title: "stats.totalHours".localized,
                    value: String(format: "%.1f%@", summary.totalHours, "time.hours.short".localized),
                    icon: "clock.fill",
                    color: .blue
                )

                summaryCard(
                    title: "stats.overtimeHours".localized,
                    value: formatOvertime(summary.overtimeSeconds),
                    icon: summary.overtimeSeconds >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill",
                    color: summary.overtimeSeconds >= 0 ? .green : .red
                )

                summaryCard(
                    title: "stats.workDays".localized,
                    value: "\(summary.workDaysCount)",
                    icon: "calendar.badge.checkmark",
                    color: .purple
                )

                summaryCard(
                    title: "charts.averagePerDay".localized,
                    value: String(format: "%.1f%@", summary.averageHours, "time.hours.short".localized),
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange
                )
            }
        }
        .padding()
        .dsGlassSurface(cornerRadius: DS.Radius.card)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    private func formatOvertime(_ seconds: Int) -> String {
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60
        let sign = seconds < 0 ? "-" : "+"
        return String(format: "%@%d%@%02d", sign, hours, "time.hours.short".localized, minutes)
    }
}
