import SwiftUI
import SwiftData

struct HomeTabView: View {
    // MARK: - Environment & State Properties
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]
    @StateObject private var timerManager: WorkTimerManager = WorkTimerManager()
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - State Properties
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var selectedWeek: Date
    
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
    
    // MARK: - Computed Properties
    var yearlyStats: (totalHours: Double, overtimeSeconds: Int) {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: selectedYear))!
        let endOfYear = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear)!
        
        return calculateStats(from: startOfYear, to: endOfYear)
    }
    
    var monthlyStats: (totalHours: Double, overtimeSeconds: Int) {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        return calculateStats(from: startOfMonth, to: endOfMonth)
    }
    
    var weeklyStats: (totalHours: Double, overtimeSeconds: Int) {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeek))!
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
        
        return calculateStats(from: startOfWeek, to: endOfWeek)
    }
    
    var vacationStats: (used: Double, remaining: Double) {
        let currentYear = Calendar.current.component(.year, from: Date())
        let thisYearWorkDays = workDays.filter {
            Calendar.current.component(.year, from: $0.date) == currentYear
        }
        
        let vacationDays = thisYearWorkDays.reduce(0.0) { total, day in
            if day.type == .vacation {
                return total + 1
            } else if day.type == .halfDayVacation {
                return total + 0.5
            }
            return total
        }
        
        return (
            used: vacationDays,
            remaining: Double(settings.annualVacationDays) - vacationDays
        )
    }
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TimerSection(timerManager: timerManager)
                    .onChange(of: timerManager.state) { _, newState in
                        if newState == .finished {
                            Task {
                                await CloudService.shared.requestSync()
                            }
                        }
                    }
                
                StatsSection(
                    title: "Année \(selectedYear)",
                    icon: "calendar",
                    color: .blue,
                    stats: yearlyStats,
                    showMissingHours: false
                )
                
                StatsSection(
                    title: "Mois en cours",
                    icon: "calendar.badge.clock",
                    color: .orange,
                    stats: monthlyStats,
                    showMissingHours: true
                )
                
                StatsSection(
                    title: "Cette semaine",
                    icon: "briefcase.fill",
                    color: .green,
                    stats: weeklyStats,
                    showMissingHours: true
                )
                
                VacationSection(stats: vacationStats)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Accueil")
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .task {
            updateCurrentPeriod()
            await CloudService.shared.requestSync()
        }
        .onChange(of: workDays) { oldValue, newValue in
            if oldValue.count != newValue.count {
                Task {
                    await CloudService.shared.requestSync()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func calculateStats(from startDate: Date, to endDate: Date) -> (totalHours: Double, overtimeSeconds: Int) {
        let periodWorkDays = workDays.filter { workDay in
            workDay.date >= startDate && workDay.date <= endDate
        }
        
        let totalHours = periodWorkDays.reduce(0.0) { $0 + $1.totalHours }
        let overtimeSeconds = periodWorkDays.reduce(0) { $0 + $1.overtimeSeconds }
        
        return (totalHours, overtimeSeconds)
    }
    
    private func updateCurrentPeriod() {
        let currentDate = Date()
        let calendar = Calendar.current
        
        selectedYear = calendar.component(.year, from: currentDate)
        selectedMonth = calendar.component(.month, from: currentDate)
        selectedWeek = currentDate
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            timerManager.handleEnterBackground()
        case .active:
            timerManager.handleEnterForeground()
            Task {
                await CloudService.shared.requestSync()
            }
        default:
            break
        }
    }
}

// MARK: - Supporting Views

struct TimerSection: View {
    @ObservedObject var timerManager: WorkTimerManager
    
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
        case .notStarted: return .blue
        case .running: return .orange
        case .paused: return .green
        case .finished: return .blue
        }
    }
    
    private var timerStatusColor: Color {
        switch timerManager.state {
        case .notStarted: return .secondary
        case .running: return .green
        case .paused: return .orange
        case .finished: return .blue
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Journée de travail")
                    .font(.headline)
                Spacer()
                Text("Restant")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                TimerDisplayComponent(
                    time: timerManager.elapsedTime,
                    statusColor: timerStatusColor
                )
                
                Spacer()
                
                RemainingTimeComponent(time: timerManager.remainingTime)
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    timerManager.toggleTimer()
                }) {
                    Text(buttonText)
                        .foregroundColor(.white)
                        .padding()
                        .background(buttonColor)
                        .cornerRadius(8)
                }
                
                if timerManager.state == .running || timerManager.state == .paused {
                    Button(action: {
                        timerManager.attemptEndDay()
                    }) {
                        Text("Terminer")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .alert("Terminer la journée", isPresented: $timerManager.showEndDayAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Terminer", role: .destructive) {
                timerManager.endDay()
            }
        } message: {
            if let pauseTime = timerManager.pauseTime {
                Text("La journée sera enregistrée avec comme heure de fin \(pauseTime.formatted(date: .omitted, time: .shortened))")
            }
        }
    }
}

struct TimerDisplayComponent: View {
    let time: TimeInterval
    let statusColor: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(formatTime(time))
                .font(.system(.title2, design: .rounded))
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

struct RemainingTimeComponent: View {
    let time: TimeInterval
    
    var body: some View {
        Text(formatTime(time))
            .font(.system(.title2, design: .rounded))
            .foregroundColor(.secondary)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let roundedInterval = round(timeInterval)
        let hours = Int(roundedInterval) / 3600
        let minutes = Int(roundedInterval) / 60 % 60
        let seconds = Int(roundedInterval) % 60
        return String(format: "%dh%02dmin %02d", hours, minutes, seconds)
    }
}

struct StatsSection: View {
    let title: String
    let icon: String
    let color: Color
    let stats: (totalHours: Double, overtimeSeconds: Int)
    let showMissingHours: Bool
    
    private var overtimeText: String {
        showMissingHours ? "Heures manquantes" : "Heures supp."
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Heures travaillées")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(WorkTimeCalculations.formattedTimeInterval(stats.totalHours * 3600))
                        .font(.title)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text(overtimeText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(WorkTimeCalculations.formattedTimeInterval(Double(stats.overtimeSeconds)))
                        .font(.title)
                        .foregroundColor(stats.overtimeSeconds >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct VacationSection: View {
    let stats: (used: Double, remaining: Double)
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sun.max.fill")
                    .foregroundColor(.orange)
                Text("Vacances")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Jours restants")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", stats.remaining))
                        .font(.title)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Jours utilisés")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", stats.used))
                        .font(.title)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        HomeTabView()
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}