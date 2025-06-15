import SwiftUI
import SwiftData

struct HomeTabView: View {
    // MARK: - Environment & State Properties
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]
    
    // MARK: - State Properties
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var selectedWeek: Date
    @StateObject private var timerManager: WorkTimerManager
    @State private var animateCards = false
    
    // MARK: - Constants
    let settings = UserSettings.shared
    
    // MARK: - Initialization
    init() {
        let currentDate = Date()
        let calendar = Calendar.current
        _selectedYear = State(initialValue: calendar.component(.year, from: currentDate))
        _selectedMonth = State(initialValue: calendar.component(.month, from: currentDate))
        _selectedWeek = State(initialValue: currentDate)
        _timerManager = StateObject(wrappedValue: WorkTimerManager(modelContext: ModelContext(try! ModelContainer(for: WorkDay.self))))
    }
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Timer section (conditionally shown)
                if settings.showTimerInHome {
                    Group {
                        WorkTimerView(modelContext: modelContext)
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                    }
                    .background(Color(.systemBackground))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Stats sections - design original avec subtiles améliorations
                StatsSection(
                    title: "Année \(selectedYear)",
                    icon: "calendar",
                    color: .blue,
                    stats: yearlyStats,
                    showMissingHours: false,
                    animateIn: animateCards,
                    animationDelay: 0.1
                )
                
                StatsSection(
                    title: "Mois en cours",
                    icon: "calendar.badge.clock",
                    color: .orange,
                    stats: monthlyStats,
                    showMissingHours: true,
                    animateIn: animateCards,
                    animationDelay: 0.2
                )
                
                StatsSection(
                    title: "Cette semaine",
                    icon: "briefcase.fill",
                    color: .green,
                    stats: weeklyStats,
                    showMissingHours: true,
                    animateIn: animateCards,
                    animationDelay: 0.3
                )
                
                // Vacation section
                VacationSection(
                    stats: vacationStats,
                    animateIn: animateCards,
                    animationDelay: 0.4
                )
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Accueil")
        .onAppear {
            updateCurrentPeriod()
            
            // Animation subtile des cartes
            withAnimation(.easeOut(duration: 0.5)) {
                animateCards = true
            }
        }
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
}

// MARK: - Supporting Views
struct StatsSection: View {
    let title: String
    let icon: String
    let color: Color
    let stats: (totalHours: Double, overtimeSeconds: Int)
    let showMissingHours: Bool
    let animateIn: Bool
    let animationDelay: Double
    
    var body: some View {
        CardView {
            VStack(spacing: 10) {
                // Header
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.title3)
                    Text(title)
                        .font(.headline)
                    Spacer()
                }
                
                Divider()
                
                // Stats
                HStack {
                    // Heures travaillées
                    StatsComponent(
                        title: "Heures travaillées",
                        value: WorkTimeCalculations.formattedTimeInterval(stats.totalHours * 3600),
                        valueColor: .primary
                    )
                    
                    Spacer()
                    
                    // Heures supplémentaires ou manquantes
                    StatsComponent(
                        title: stats.overtimeSeconds >= 0 ? "Heures supp." : "Heures manquantes",
                        value: WorkTimeCalculations.formattedTimeInterval(Double(stats.overtimeSeconds)),
                        valueColor: stats.overtimeSeconds >= 0 ? .green : .red
                    )
                }
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(.easeOut(duration: 0.4).delay(animationDelay), value: animateIn)
    }
}

struct VacationSection: View {
    let stats: (used: Double, remaining: Double)
    let animateIn: Bool
    let animationDelay: Double
    
    var body: some View {
        CardView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                    Text("Congés")
                        .font(.headline)
                    Spacer()
                }
                
                Divider()
                
                // Stats
                HStack {
                    VacationStatsComponent(
                        title: "Jours restants",
                        value: stats.remaining,
                        valueColor: stats.remaining > 0 ? .primary : .red
                    )
                    
                    Spacer()
                    
                    VacationStatsComponent(
                        title: "Jours utilisés",
                        value: stats.used,
                        valueColor: .green
                    )
                }
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 20)
        .animation(.easeOut(duration: 0.4).delay(animationDelay), value: animateIn)
    }
}

struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

struct StatsComponent: View {
    let title: String
    let value: String
    let valueColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded))
                .foregroundColor(valueColor)
                .fontWeight(.medium)
        }
    }
}

struct VacationStatsComponent: View {
    let title: String
    let value: Double
    let valueColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(String(format: "%.1f j", value))
                .font(.system(.title3, design: .rounded))
                .foregroundColor(valueColor)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        HomeTabView()
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}
