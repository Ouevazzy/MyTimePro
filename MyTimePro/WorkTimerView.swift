import SwiftUI
import SwiftData

struct WorkTimerView: View {
    // MARK: - Environment & State
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var timerManager: WorkTimerManager
    @AppStorage("standardDailyHours") private var standardDailyHours: Double = 8.0
    
    // MARK: - Constants
    private struct ViewMetrics {
        static let cornerRadius: CGFloat = 16
        static let buttonHeight: CGFloat = 36
        static let shadowRadius: CGFloat = 8
        static let buttonCornerRadius: CGFloat = 10
        static let contentPadding: CGFloat = 15
        static let spacing: CGFloat = 8
        static let statusIndicatorSize: CGFloat = 8
    }
    
    // MARK: - Initialization
    init(modelContext: ModelContext) {
        _timerManager = StateObject(wrappedValue: WorkTimerManager(modelContext: modelContext))
    }
    
    // MARK: - Computed Properties
    private var buttonText: String {
        switch timerManager.state {
        case .notStarted:
            return "Démarrer"
        case .running:
            return "Pause"
        case .paused:
            return "Reprendre"
        case .finished:
            return "Nouvelle"
        }
    }
    
    private var timerStatusColor: Color {
        switch timerManager.state {
        case .notStarted:
            return .secondary
        case .running:
            return .green
        case .paused:
            return .orange
        case .finished:
            return .blue
        }
    }
    
    private var buttonColor: Color {
        switch timerManager.state {
        case .notStarted:
            return .blue
        case .running:
            return .orange
        case .paused:
            return .green
        case .finished:
            return .blue
        }
    }
    
    // MARK: - Main View
    var body: some View {
        VStack(spacing: ViewMetrics.contentPadding) {
            timerHeader
            controlButtons
        }
        .padding()
        .background(background)
        .padding(.horizontal)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .alert("Terminer la journée", isPresented: $timerManager.showEndDayAlert) {
            endDayAlertButtons
        } message: {
            endDayAlertMessage
        }
    }
    
    // MARK: - View Components
    private var timerHeader: some View {
        HStack(spacing: 20) {
            elapsedTimeView
            Spacer()
            remainingTimeView
        }
    }
    
    private var elapsedTimeView: some View {
        VStack(alignment: .leading, spacing: ViewMetrics.spacing) {
            Text("Journée de travail")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: ViewMetrics.spacing) {
                Circle()
                    .fill(timerStatusColor)
                    .frame(width: ViewMetrics.statusIndicatorSize, height: ViewMetrics.statusIndicatorSize)
                
                Text(formatTime(timerManager.elapsedTime))
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .fixedSize()
            }
        }
    }
    
    private var remainingTimeView: some View {
        VStack(alignment: .trailing, spacing: ViewMetrics.spacing) {
            Text("Restant")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(formatTime(timerManager.remainingTime))
                .font(.system(.title3, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize()
        }
    }
    
    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button(action: {
                timerManager.toggleTimer()
            }) {
                buttonLabel(text: buttonText, color: buttonColor)
            }
            
            if timerManager.state == .running || timerManager.state == .paused {
                Button(action: {
                    timerManager.attemptEndDay()
                }) {
                    buttonLabel(text: "Terminer", color: .red)
                }
            }
        }
    }
    
    private var background: some View {
        RoundedRectangle(cornerRadius: ViewMetrics.cornerRadius)
            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                radius: ViewMetrics.shadowRadius,
                x: 0,
                y: 2
            )
    }
    
    private var endDayAlertButtons: some View {
        Group {
            Button("Annuler", role: .cancel) { }
            Button("Terminer", role: .destructive) {
                timerManager.endDay()
            }
        }
    }
    
    private var endDayAlertMessage: some View {
        Group {
            if let pauseTime = timerManager.pauseTime {
                Text("La journée sera enregistrée avec comme heure de fin \(pauseTime.formatted(date: .omitted, time: .shortened))")
            }
        }
    }
    
    // MARK: - Helper Methods
    private func buttonLabel(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(.body, design: .rounded))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: ViewMetrics.buttonHeight)
            .background(color)
            .cornerRadius(ViewMetrics.buttonCornerRadius)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let roundedInterval = round(timeInterval)
        let hours = Int(roundedInterval) / 3600
        let minutes = Int(roundedInterval) / 60 % 60
        let seconds = Int(roundedInterval) % 60
        return String(format: "%dh%02dmin %02d", hours, minutes, seconds)
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            timerManager.handleEnterBackground()
        case .active:
            timerManager.handleEnterForeground()
        default:
            break
        }
    }
}

// MARK: - Preview
#Preview {
    WorkTimerView(modelContext: ModelContext(try! ModelContainer(for: WorkDay.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))))
        .preferredColorScheme(.dark)
}

// MARK: - Supporting Views
struct TimeDisplayView: View {
    let title: String
    let time: String
    let isTitleSecondary: Bool
    let alignment: HorizontalAlignment
    
    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(title)
                .font(isTitleSecondary ? .subheadline : .headline)
                .foregroundColor(isTitleSecondary ? .secondary : .primary)
            
            Text(time)
                .font(.system(.title2, design: .rounded))
                .foregroundColor(isTitleSecondary ? .secondary : .primary)
                .fixedSize()
        }
    }
}
