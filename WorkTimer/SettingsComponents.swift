import SwiftUI

// MARK: - Enums

enum SettingsSection {
    case workTime, display, features, privacy, export, about, reset, subscription
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { self.rawValue }
}

enum ExportType: Identifiable {
    case monthly, annual
    var id: Int {
        switch self {
        case .monthly: return 1
        case .annual: return 2
        }
    }
}

enum ExportFormat: Equatable {
    case pdf, csv
}

// MARK: - SettingsCard

private struct SettingsGroupedRowsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var settingsGroupedRows: Bool {
        get { self[SettingsGroupedRowsKey.self] }
        set { self[SettingsGroupedRowsKey.self] = newValue }
    }
}

struct SettingsGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .dsContentSurface()
        .environment(\.settingsGroupedRows, true)
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let isExpanded: Bool
    let onToggle: () -> Void
    let content: Content
    @Environment(\.settingsGroupedRows) private var groupedRows

    init(
        title: String, icon: String, color: Color,
        isExpanded: Bool, onToggle: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title; self.icon = icon; self.color = color
        self.isExpanded = isExpanded; self.onToggle = onToggle
        self.content = content()
    }

    var body: some View {
        if groupedRows {
            cardContent
        } else {
            cardContent.dsContentSurface()
        }
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            Button(action: { onToggle() }) {
                HStack(spacing: DS.Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.IconRadius.settings)
                            .fill(color)
                            .frame(width: DS.IconSize.sectionHeader, height: DS.IconSize.sectionHeader)
                        Image(systemName: icon)
                            .font(.system(size: DS.Font.iconSmall, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(DS.Animation.cardToggle, value: isExpanded)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "accessibility.expanded".localized : "accessibility.collapsed".localized)
            if isExpanded {
                content.transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
        }
    }
}

// MARK: - StatisticCard

struct StatisticCard: View {
    let title: String; let value: String
    let icon: String; let color: Color
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: DS.IconSize.inline, height: DS.IconSize.inline)
                    .background(color, in: RoundedRectangle(cornerRadius: DS.IconRadius.inline))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .dsContentSurface(cornerRadius: DS.Radius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - FeatureButton

struct FeatureButton: View {
    let title: String; let subtitle: String
    let icon: String; let color: Color
    var isPro: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(color, in: RoundedRectangle(cornerRadius: DS.IconRadius.inline))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).fontWeight(.medium).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if isPro {
                    Text("PRO")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.orange, in: Capsule())
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.md)
            .dsContentSurface(cornerRadius: DS.Radius.medium)
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - PrivacyFeatureRow

struct PrivacyFeatureRow: View {
    let icon: String; let text: String; let color: Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 24)
            Text(text).font(.subheadline).foregroundStyle(.primary)
            Spacer()
        }
    }
}

// MARK: - ConfettiView

struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confetti: [ConfettiPiece] = []
    @State private var animate = false

    struct ConfettiPiece: Identifiable {
        let id = UUID(); let color: Color
        let startX: CGFloat; let endX: CGFloat
        let rotation: Double; let endRotation: Double
        let size: CGFloat; let animationDelay: Double
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confetti) { piece in
                    Circle().fill(piece.color).frame(width: piece.size, height: piece.size)
                        .position(
                            x: animate ? piece.endX : piece.startX,
                            y: animate ? geometry.size.height + 50 : -20
                        )
                        .rotationEffect(.degrees(animate ? piece.endRotation : piece.rotation))
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeOut(duration: Double.random(in: 1.5...3.0))
                            .delay(piece.animationDelay),
                            value: animate
                        )
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                generateConfetti(in: geometry.size.width)
                animate = true
            }
        }
        .drawingGroup()
    }

    private func generateConfetti(in availableWidth: CGFloat) {
        let colors: [Color] = [.red, .blue, .green, .yellow, .purple, .orange, .pink, .mint]
        // Les fenêtres iPhone peuvent maintenant être redimensionnées. Les
        // particules couvrent donc toute la largeur disponible, au lieu d'une
        // zone fixe optimisée seulement pour les iPhone historiques.
        let horizontalInset: CGFloat = 12
        let upperBound = max(horizontalInset, availableWidth - horizontalInset)
        confetti = (0..<60).map { _ in
            let startX = CGFloat.random(in: horizontalInset...upperBound)
            return ConfettiPiece(
                color: colors.randomElement()!,
                startX: startX,
                endX: startX + CGFloat.random(in: -80...80),
                rotation: Double.random(in: 0...360),
                endRotation: Double.random(in: 360...1080),
                size: CGFloat.random(in: 4...10),
                animationDelay: Double.random(in: 0...0.4)
            )
        }
    }
}

// MARK: - Extensions

extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
