import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]
    @State private var selectedDate = Date()
    @State private var showingAddWorkDay = false
    @State private var showingEditSheet = false
    @State private var selectedWorkDay: WorkDay?
    
    private let calendar = Calendar.current
    private let daysInWeek = 7
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    // Jours de la semaine commençant par lundi
    private let weekDaySymbols: [String] = {
        var symbols = Calendar.current.shortWeekdaySymbols
        let sunday = symbols.remove(at: 0)
        symbols.append(sunday)
        return symbols.map { $0.lowercased() }
    }()
    
    private var monthDates: [Date?] {
        let interval = calendar.dateInterval(of: .month, for: selectedDate)!
        let firstDayOfMonth = interval.start
        
        let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: firstDayOfMonth)!.count
        
        // Ajustement pour commencer le lundi
        var firstWeekday = calendar.component(.weekday, from: firstDayOfMonth) - 2
        if firstWeekday < 0 { firstWeekday += 7 }
        
        var dates: [Date?] = []
        
        for _ in 0..<firstWeekday {
            dates.append(nil)
        }
        
        for dayOffset in 0..<numberOfDaysInMonth {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstDayOfMonth) {
                dates.append(date)
            }
        }
        
        while (dates.count % 7) != 0 {
            dates.append(nil)
        }
        
        return dates
    }
    
    private var monthAndYear: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: selectedDate).lowercased()
    }
    
    // Vérifie si la date sélectionnée est aujourd'hui
    private var isSelectedDateToday: Bool {
        calendar.isDateInToday(selectedDate)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // En-tête avec le mois et les boutons de navigation
                    HStack {
                        Button(action: previousMonth) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                        
                        Spacer()
                        
                        Text(monthAndYear)
                            .font(.title2)
                        
                        Spacer()
                        
                        Button(action: nextMonth) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Bouton Aujourd'hui
                    if !isSelectedDateToday {
                        Button(action: goToToday) {
                            Text("Aujourd'hui")
                                .foregroundColor(.blue)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 12)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 1)
                        }
                    }
                    
                    // Jours de la semaine
                    HStack {
                        ForEach(weekDaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Grille des jours
                    LazyVGrid(columns: columns, spacing: 1) {
                        ForEach(Array(monthDates.enumerated()), id: \.offset) { index, date in
                            if let date = date {
                                let workDay = findWorkDay(for: date)
                                CalendarCell(
                                    date: date,
                                    workDay: workDay,
                                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                                )
                                .onTapGesture {
                                    withAnimation {
                                        selectedDate = date
                                        selectedWorkDay = workDay
                                    }
                                }
                            } else {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fill)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Affichage des détails de la journée sélectionnée
                    if let workDay = selectedWorkDay {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(formatDate(workDay.date))
                                .font(.headline)
                                .padding(.horizontal)
                            
                            List {
                                CalendarDetailRow(workDay: workDay)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        showingEditSheet = true
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                deleteWorkDay(workDay)
                                            }
                                        } label: {
                                            Label("Supprimer", systemImage: "trash")
                                        }
                                    }
                            }
                            .listStyle(.plain)
                            .frame(height: 100)
                        }
                        .padding(.vertical)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Calendrier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddWorkDay = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkDay) {
                NavigationStack {
                    AddEditWorkDayView(
                        workDay: WorkDay(date: calendar.startOfDay(for: selectedDate))
                    )
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                if let workDay = selectedWorkDay {
                    NavigationStack {
                        AddEditWorkDayView(workDay: workDay)
                    }
                }
            }
        }
    }
    
    private func deleteWorkDay(_ workDay: WorkDay) {
        modelContext.delete(workDay)
        try? modelContext.save()
        selectedWorkDay = nil
    }
    
    private func goToToday() {
        withAnimation {
            selectedDate = Date()
            selectedWorkDay = findWorkDay(for: selectedDate)
        }
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
            withAnimation {
                selectedDate = newDate
                selectedWorkDay = nil
            }
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
            withAnimation {
                selectedDate = newDate
                selectedWorkDay = nil
            }
        }
    }
    
    private func findWorkDay(for date: Date) -> WorkDay? {
        workDays.first { workDay in
            calendar.isDate(workDay.date, inSameDayAs: date)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .full
        return formatter.string(from: date).capitalized
    }
}

struct CalendarDetailRow: View {
    let workDay: WorkDay
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Section gauche avec type et heures
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: workDay.type.icon)
                        .foregroundColor(workDay.type.color)
                    Text(workDay.type.rawValue)
                        .font(.headline)
                }
                
                if workDay.type == .work {
                    Text(workDay.formattedTotalHours)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            if let note = workDay.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundColor(.blue)
                    .italic()
                    .lineLimit(3)
                    .padding(.horizontal, 4)
            }
            
            Spacer()
            
            // Section droite avec heures supp et bonus
            if workDay.type == .work {
                VStack(alignment: .trailing, spacing: 4) {
                    if workDay.overtimeSeconds != 0 {
                        Text(workDay.formattedOvertimeHours)
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
        .padding(.horizontal)
    }
}

struct CalendarCell: View {
    let date: Date
    let workDay: WorkDay?
    let isSelected: Bool
    private let calendar = Calendar.current
    
    private var dayNumber: String {
        String(calendar.component(.day, from: date))
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
            
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(isSelected ? .blue : .primary)
                
                if let workDay = workDay {
                    Image(systemName: workDay.type.icon)
                        .foregroundStyle(workDay.type.color)
                        .font(.caption)
                    
                    // Affichage du bonus si présent
                    if workDay.bonusAmount > 0 {
                        Text("+" + String(format: "%.0f", workDay.bonusAmount))
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .aspectRatio(1, contentMode: .fill)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .blue.opacity(0.2)
        }
        if workDay != nil {
            return Color(.systemGray6)
        }
        return .clear
    }
}
