import SwiftUI
import SwiftData
import QuartzCore

// MARK: - Constants
struct ViewMetrics {
    static let cornerRadius: CGFloat = 16
    static let buttonHeight: CGFloat = 36
    static let shadowRadius: CGFloat = 8
    static let buttonCornerRadius: CGFloat = 10
    static let contentPadding: CGFloat = 15
    static let spacing: CGFloat = 8
    static let statusIndicatorSize: CGFloat = 8
}

struct WorkTimerView: View {
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("standardDailyHours") private var standardDailyHours: Double = 8.0
    @StateObject private var timerManager: WorkTimerManager
    
    // MARK: - Initialization
    init(modelContext: ModelContext) {
        _timerManager = StateObject(wrappedValue: WorkTimerManager(modelContext: modelContext))
    }
    
    // MARK: - Body
    var body: some View {
        StandardCardView(
            cornerRadiusAmount: ViewMetrics.cornerRadius, // Specific to WorkTimerView (16)
            backgroundColor: colorScheme == .dark ? Color(.secondarySystemGroupedBackground) : Color(.systemBackground), // Match original adaptive bg
            // Using default shadow from StandardCardView for consistency, though original was different
            shadowColor: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.08), // Slightly adjusted shadow for context
            shadowRadius: colorScheme == .dark ? 6 : 4,
            shadowY: colorScheme == .dark ? 3 : 2
        ) {
            VStack(spacing: ViewMetrics.contentPadding) {
                // Timer Display
                HStack(spacing: 20) {
                    elapsedTimeView
                    Spacer()
                    remainingTimeView
                }
                .contentTransition(.numericText())
                
                // Controls
                HStack(spacing: 12) {
                    mainActionButton

                    if timerManager.state == .running || timerManager.state == .paused {
                        endDayButton
                    }
                }
            }
        }
        // .padding() // This padding is now handled by StandardCardView's paddingAmount (default 16)
        // Background and shadow are handled by StandardCardView
        .padding(.horizontal) // This outer padding for the card itself remains
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .alert("Terminer la journée", isPresented: $timerManager.showEndDayAlert) {
            Group {
                Button("Annuler", role: .cancel) { }
                Button("Terminer", role: .destructive) {
                    timerManager.endDay()
                }
            }
        } message: {
            if let pauseTime = timerManager.pauseTime {
                Text("La journée sera enregistrée avec comme heure de fin \(pauseTime.formatted(date: .omitted, time: .shortened))")
            }
        }
    }
    
    // MARK: - Components
    private var elapsedTimeView: some View {
        VStack(alignment: .leading, spacing: ViewMetrics.spacing) {
            Text("Journée de travail")
                .font(.headline)
                .foregroundStyle(.primary)
            
            HStack(spacing: ViewMetrics.spacing) {
                Circle()
                    .fill(timerStatusColor)
                    .frame(width: ViewMetrics.statusIndicatorSize, height: ViewMetrics.statusIndicatorSize)
                    .symbolEffect(.pulse, options: .repeating, isActive: timerManager.state == .running)
                
                Text(formatTime(timerManager.elapsedTime))
                    .font(.system(.title2, design: .rounded))
                    .monospacedDigit()
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .fixedSize()
            }
        }
    }
    
    private var remainingTimeView: some View {
        VStack(alignment: .trailing, spacing: ViewMetrics.spacing) {
            Text("Restant")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(formatTime(timerManager.remainingTime))
                .font(.system(.title3, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .fixedSize()
        }
    }
    
    private var mainActionButton: some View {
        Button(action: { timerManager.toggleTimer() }) {
            TimerButtonLabel(text: buttonText, color: buttonColor)
        }
    }
    
    private var endDayButton: some View {
        Button(action: { timerManager.showEndDayAlert = true }) {
            TimerButtonLabel(text: "Terminer", color: .red)
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
    
    // MARK: - Computed Properties
    private var buttonText: String {
        switch timerManager.state {
        case .notStarted: return "Démarrer"
        case .running: return "Pause"
        case .paused: return "Reprendre"
        case .finished: return "Nouvelle"
        }
    }
    
    private var buttonColor: Color {
        switch timerManager.state {
        case .notStarted: return ThemeManager.shared.currentAccentColor
        case .running: return .orange // Semantic
        case .paused: return .green // Semantic
        case .finished: return ThemeManager.shared.currentAccentColor
        }
    }
    
    private var timerStatusColor: Color {
        switch timerManager.state {
        case .notStarted: return .secondary // Neutral, keep as is
        case .running: return .green // Semantic
        case .paused: return .orange // Semantic
        case .finished: return ThemeManager.shared.currentAccentColor
        }
    }
    
    // MARK: - Helper Methods
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Sauvegarde l'état lorsque l'app passe en arrière-plan
            if timerManager.state == .running {
                timerManager.pauseTimer()
            }
        case .active:
            // Optionnel: restaurer l'état quand l'app revient au premier plan
            // Ne rien faire de particulier ici pour notre cas
            break
        default:
            break
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let roundedInterval = round(timeInterval)
        let hours = Int(roundedInterval) / 3600
        let minutes = Int(roundedInterval) / 60 % 60
        let seconds = Int(roundedInterval) % 60
        return String(format: "%dh%02dmin %02d", hours, minutes, seconds)
    }
}

// MARK: - Supporting Views
private struct TimerButtonLabel: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(.body, design: .rounded))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: ViewMetrics.buttonHeight)
            .background(color)
            .cornerRadius(ViewMetrics.buttonCornerRadius)
    }
}

// MARK: - Preview
#Preview {
    WorkTimerView(modelContext: ModelContext(try! ModelContainer(for: WorkDay.self, configurations: ModelConfiguration())))
        .preferredColorScheme(.dark)
}
