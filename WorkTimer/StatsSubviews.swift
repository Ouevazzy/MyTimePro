//
//  StatsSubviews.swift
//  WorkTimer
//
//  Composants d'affichage des statistiques extraits de StatsView.
//

import SwiftUI

// MARK: - MonthStatContent

struct MonthStatContent: View, Equatable {
    let monthStat: MonthStats
    let formattedHours: String
    let formattedOvertime: String
    let formattedVacation: String
    let formattedSickDays: String
    let formattedBonus: String
    var formattedEarnings: String? = nil
    let overtimeSeconds: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    static func == (lhs: MonthStatContent, rhs: MonthStatContent) -> Bool {
        lhs.formattedHours == rhs.formattedHours &&
        lhs.formattedOvertime == rhs.formattedOvertime &&
        lhs.formattedVacation == rhs.formattedVacation &&
        lhs.formattedSickDays == rhs.formattedSickDays &&
        lhs.formattedBonus == rhs.formattedBonus &&
        lhs.formattedEarnings == rhs.formattedEarnings &&
        lhs.overtimeSeconds == rhs.overtimeSeconds &&
        lhs.monthStat.month == rhs.monthStat.month &&
        lhs.monthStat.workDays == rhs.monthStat.workDays &&
        lhs.monthStat.vacationDays == rhs.monthStat.vacationDays &&
        lhs.monthStat.sickDays == rhs.monthStat.sickDays &&
        lhs.monthStat.totalBonus == rhs.monthStat.totalBonus
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.md))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.xl))

        return VStack(spacing: DS.Spacing.md) {
            layout {
                StatDataCell(
                    label: "stats.workedHours".localized,
                    value: formattedHours,
                    valueColor: .primary
                )
                StatDataCell(
                    label: overtimeSeconds < 0 ? "stats.missingHours".localized : "stats.overtimeHours".localized,
                    value: formattedOvertime,
                    valueColor: DS.Colors.balance(Double(overtimeSeconds)),
                    trendUp: overtimeSeconds == 0 ? nil : overtimeSeconds > 0
                )
            }

            if monthStat.vacationDays > 0 || monthStat.sickDays > 0 {
                layout {
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
                            value: formattedSickDays,
                            valueColor: .primary
                        )
                    }
                    if !dynamicTypeSize.isAccessibilitySize && (monthStat.vacationDays == 0 || monthStat.sickDays == 0) {
                        Spacer()
                    }
                }
            }

            if monthStat.totalBonus > 0 {
                HStack {
                    Text("stats.bonus".localized)
                        .font(.subheadline)
                        .foregroundStyle(DS.Colors.secondaryText)
                    Spacer()
                    Text(formattedBonus)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
            }

            if let formattedEarnings {
                HStack {
                    Text("stats.earnings".localized)
                        .font(.subheadline)
                        .foregroundStyle(DS.Colors.secondaryText)
                    Spacer()
                    Text(formattedEarnings)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

// MARK: - StatDataCell

struct StatDataCell: View {
    let label: String
    let value: String
    let valueColor: Color
    /// Si défini, affiche une flèche directionnelle (forme) en plus de la couleur,
    /// conforme aux HIG : ne pas transmettre une information par la seule couleur.
    var trendUp: Bool? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(DS.Colors.secondaryText)
            HStack(spacing: 3) {
                if let trendUp {
                    Image(systemName: trendUp ? "arrow.up" : "arrow.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(valueColor)
                        .accessibilityHidden(true)
                }
                Text(value)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
            }
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
    let valueColor: Color

    static func == (lhs: StatCard, rhs: StatCard) -> Bool {
        lhs.icon == rhs.icon &&
        lhs.iconColor == rhs.iconColor &&
        lhs.value == rhs.value &&
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle &&
        lhs.valueColor == rhs.valueColor
    }

    init(icon: String, iconColor: Color, value: String, title: String, subtitle: String? = nil, valueColor: Color = .primary) {
        self.icon = icon
        self.iconColor = iconColor
        self.value = value
        self.title = title
        self.subtitle = subtitle
        self.valueColor = valueColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)
                Text(title)
                    .foregroundStyle(DS.Colors.secondaryText)
            }
            .font(.subheadline)

            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)" + (subtitle != nil ? ", \(subtitle!)" : ""))
    }
}

struct StatSummaryRow: View {
    let icon: String
    let title: String
    let value: String
    var subtitle: String? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DS.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: DS.Spacing.md))

        layout {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(DS.Colors.secondaryText)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: DS.Spacing.sm)
            }
            VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: DS.Spacing.xs) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DS.Colors.secondaryText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
