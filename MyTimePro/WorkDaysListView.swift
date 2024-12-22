import SwiftUI
import SwiftData

struct WorkDaysListView: View {
    // MARK: - Properties
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]
    
    @State private var showAddWorkDayView = false
    @State private var selectedWorkDay: WorkDay?
    @State private var selectedMonth = Date()
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    
    private var currentMonth: Int {
        Calendar.current.component(.month, from: selectedMonth)
    }
    
    private var isCurrentMonth: Bool {
        let calendar = Calendar.current
        let currentDate = Date()
        return calendar.component(.month, from: currentDate) == currentMonth &&
               calendar.component(.year, from: currentDate) == selectedYear
    }
    
    private var groupedWorkDays: [String: [WorkDay]] {
        Dictionary(grouping: filterWorkDays(), by: { workDay in
            workDay.date.formatted(date: .abbreviated, time: .omitted)
        })
    }
    
    private var monthlyStats: (totalHours: Double, overtimeSeconds: Int, totalBonus: Double) {
        let filtered = filterWorkDays()
        let totalHours = filtered.reduce(0) { $0 + $1.totalHours }
        let overtimeSeconds = filtered.reduce(0) { $0 + $1.overtimeSeconds }
        let totalBonus = filtered.reduce(0) { $0 + $1.bonusAmount }
        return (totalHours, overtimeSeconds, totalBonus)
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // En-tête avec le nom du mois et navigation
                monthNavigationHeader
                
                // Statistiques mensuelles
                MonthlyStatsHeader(stats: monthlyStats)
                
                // Liste des jours de travail
                workDaysList
            }
            .navigationTitle("Journées de Travail")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    addButton
                }
            }
            .sheet(isPresented: $showAddWorkDayView) {
                NavigationStack {
                    AddEditWorkDayView(workDay: WorkDay(date: Date(), type: .work))
                }
            }
            .sheet(item: $selectedWorkDay) { workDay in
                NavigationStack {
                    AddEditWorkDayView(workDay: workDay)
                }
            }
        }
    }
    
    // MARK: - Views Components
    private var monthNavigationHeader: some View {
        HStack {
            Button(action: { navigateToPreviousMonth() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(monthYearString)
                    .font(.headline)
                
                if !isCurrentMonth {
                    Button(action: { navigateToCurrentMonth() }) {
                        Text("Aujourd'hui")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            Button(action: { navigateToNextMonth() }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    private var workDaysList: some View {
        List {
            ForEach(groupedWorkDays.keys.sorted(by: >), id: \.self) { date in
                if let days = groupedWorkDays[date] {
                    Section(header: CustomSectionHeader(date: date, isToday: isToday(date))) {
                        ForEach(days) { workDay in
                            WorkDayRow(workDay: workDay)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedWorkDay = workDay
                                }
                        }
                        .onDelete { indexSet in
                            deleteWorkDays(days, at: indexSet)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var addButton: some View {
        Button(action: {
            showAddWorkDayView = true
        }) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
        }
    }
    
    // MARK: - Helper Methods
    private func filterWorkDays() -> [WorkDay] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        return workDays.filter { workDay in
            workDay.date >= startOfMonth && workDay.date <= endOfMonth
        }
    }
    
    private func deleteWorkDays(_ days: [WorkDay], at offsets: IndexSet) {
        withAnimation {
            offsets.forEach { index in
                let workDay = days[index]
                modelContext.delete(workDay)
            }
            try? modelContext.save()
        }
    }
    
    private func navigateToPreviousMonth() {
        let calendar = Calendar.current
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            withAnimation {
                selectedMonth = previousMonth
                selectedYear = calendar.component(.year, from: previousMonth)
            }
        }
    }
    
    private func navigateToNextMonth() {
        let calendar = Calendar.current
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            withAnimation {
                selectedMonth = nextMonth
                selectedYear = calendar.component(.year, from: nextMonth)
            }
        }
    }
    
    private func navigateToCurrentMonth() {
        let currentDate = Date()
        withAnimation {
            selectedMonth = currentDate
            selectedYear = Calendar.current.component(.year, from: currentDate)
        }
    }
    
    private func isToday(_ dateString: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        if let date = formatter.date(from: dateString) {
            return Calendar.current.isDateInToday(date)
        }
        return false
    }
    
    private var monthYearString: String {
        selectedMonth.formatted(.dateTime.month(.wide).year())
    }
}

// MARK: - Supporting Views
struct MonthlyStatsHeader: View {
    let stats: (totalHours: Double, overtimeSeconds: Int, totalBonus: Double)
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatBox(
                    title: "Total",
                    value: WorkTimeCalculations.formattedTimeInterval(stats.totalHours * 3600),
                    icon: "clock.fill",
                    color: .blue
                )
                
                StatBox(
                    title: "Supp.",
                    value: WorkTimeCalculations.formattedTimeInterval(Double(stats.overtimeSeconds)),
                    icon: "clock.badge.exclamationmark.fill",
                    color: stats.overtimeSeconds >= 0 ? .green : .red
                )
                
                if stats.totalBonus > 0 {
                    StatBox(
                        title: "Bonus",
                        value: String(format: "%.0f", stats.totalBonus),
                        icon: "dollarsign.circle.fill",
                        color: .orange
                    )
                }
            }
            .padding()
            
            Divider()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
}

struct CustomSectionHeader: View {
    let date: String
    let isToday: Bool
    
    var body: some View {
        HStack {
            Text(date)
                .font(.headline)
                .foregroundColor(.primary)
            
            if isToday {
                Text("Aujourd'hui")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .cornerRadius(4)
            }
        }
        .textCase(nil)
    }
}

struct WorkDayRow: View {
    let workDay: WorkDay
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: workDay.type.icon)
                        .foregroundColor(workDay.type.color)
                    Text(workDay.type.rawValue)
                        .font(.headline)
                }
                
                if workDay.type == .work {
                    Text("\(workDay.formattedTotalHours)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let note = workDay.note, !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .italic()
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if workDay.type == .work {
                VStack(alignment: .trailing, spacing: 4) {
                    if workDay.overtimeSeconds != 0 {
                        Text(WorkTimeCalculations.formattedTimeInterval(Double(workDay.overtimeSeconds)))
                            .font(.subheadline)
                            .foregroundColor(workDay.overtimeSeconds > 0 ? .green : .red)
                    }
                    
                    if workDay.bonusAmount > 0 {
                        Text("Bonus: \(workDay.bonusAmount, specifier: "%.0f")")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        WorkDaysListView()
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}
