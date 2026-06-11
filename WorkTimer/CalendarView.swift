import SwiftUI
import SwiftData
import TipKit

enum CalendarViewMode: Hashable {
    case month
    case week
}

struct CalendarMonthSlot: Identifiable, Hashable {
    let id: String
    let date: Date?
}

/// Identifiant stable pour relancer le chargement SwiftData (période, mode, ou invalidation explicite).
private struct CalendarLoadIdentity: Hashable {
    let displayDate: Date
    let mode: CalendarViewMode
    let dataRevision: Int
}

/// Calculs purs de grille, dérivés directement du mois ou de la semaine affichée.
enum CalendarGridLayout {
    static var displayCalendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    static func dateIdentity(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: calendar.startOfDay(for: date))
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func monthDisplayDate(for date: Date, calendar: Calendar) -> Date {
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return calendar.startOfDay(for: date)
        }
        return calendar.startOfDay(for: interval.start)
    }

    static func weekdaySymbols(for calendar: Calendar) -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        guard !symbols.isEmpty else { return [] }

        let firstIndex = min(max(calendar.firstWeekday - 1, 0), symbols.count - 1)
        return (Array(symbols[firstIndex...]) + Array(symbols[..<firstIndex]))
            .map { $0.lowercased() }
    }

    static func monthDates(for date: Date, calendar: Calendar) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return []
        }

        let firstDayOfMonth = calendar.startOfDay(for: interval.start)
        guard let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: firstDayOfMonth)?.count else {
            return []
        }

        let startDayIndex = (calendar.component(.weekday, from: firstDayOfMonth) - calendar.firstWeekday + 7) % 7

        var dates: [Date?] = []
        for _ in 0..<startDayIndex {
            dates.append(nil)
        }
        for dayOffset in 0..<numberOfDaysInMonth {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstDayOfMonth) {
                dates.append(calendar.startOfDay(for: date))
            }
        }
        while dates.count % 7 != 0 {
            dates.append(nil)
        }
        return dates
    }

    static func monthSlots(for date: Date, calendar: Calendar) -> [CalendarMonthSlot] {
        let monthID = dateIdentity(for: monthDisplayDate(for: date, calendar: calendar), calendar: calendar)

        return monthDates(for: date, calendar: calendar).enumerated().map { index, date in
            if let date {
                return CalendarMonthSlot(
                    id: "day-\(dateIdentity(for: date, calendar: calendar))",
                    date: date
                )
            }

            return CalendarMonthSlot(id: "empty-\(monthID)-\(index)", date: nil)
        }
    }

    static func monthNavigation(
        from displayDate: Date,
        preferredDay: Int,
        by offset: Int,
        calendar: Calendar
    ) -> (displayDate: Date, selectedDate: Date)? {
        let sourceMonth = monthDisplayDate(for: displayDate, calendar: calendar)
        guard let shiftedMonth = calendar.date(byAdding: .month, value: offset, to: sourceMonth) else {
            return nil
        }

        let targetMonth = monthDisplayDate(for: shiftedMonth, calendar: calendar)
        let numberOfDays = calendar.range(of: .day, in: .month, for: targetMonth)?.count ?? preferredDay
        let selectedDay = min(max(preferredDay, 1), numberOfDays)
        var components = calendar.dateComponents([.year, .month], from: targetMonth)
        components.day = selectedDay

        guard let selectedDate = calendar.date(from: components) else {
            return nil
        }

        return (
            displayDate: targetMonth,
            selectedDate: calendar.startOfDay(for: selectedDate)
        )
    }

    static func weekDates(for date: Date, calendar: Calendar) -> [Date] {
        let normalizedDate = calendar.startOfDay(for: date)
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: normalizedDate)) else {
            return []
        }
        return (0...6).compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day, to: weekStart) else {
                return nil
            }
            return calendar.startOfDay(for: date)
        }
    }
}

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Binding private var focusedDate: Date?
    
    // État principal
    @State private var selectedDate: Date
    @State private var displayDate: Date
    @State private var calendarViewMode: CalendarViewMode = .month
    @State private var calendarDataRevision = 0
    @State private var preferredDayOfMonth: Int
    
    // Gestion des feuilles modales
    @State private var showingAddWorkDay = false
    @State private var showingEditSheet = false
    @State private var selectedWorkDay: WorkDay?
    @State private var showingDatePicker = false
    
    // Animation du mois
    @State private var slideDirection: SlideDirection = .none
    @State private var dragOffset: CGFloat = 0

    // Nouvelles optimisations
    @State private var workDaysByDate: [Date: WorkDay] = [:]  // Lookup O(1) au lieu de O(n)
    @State private var isFiltering = false
    
    // Valeurs calculées
    private let calendar = CalendarGridLayout.displayCalendar
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    // Constantes d'animation
    private enum SlideDirection {
        case none, left, right
    }
    
    // Animation de transition entre les mois
    @Namespace private var monthTransition
    private let addWorkDayTip = CalendarAddWorkDayTip()

    init(focusedDate: Binding<Date?> = .constant(nil)) {
        let calendar = CalendarGridLayout.displayCalendar
        let initialDate = calendar.startOfDay(for: focusedDate.wrappedValue ?? Date())

        _focusedDate = focusedDate
        _selectedDate = State(initialValue: initialDate)
        _displayDate = State(initialValue: CalendarGridLayout.monthDisplayDate(for: initialDate, calendar: calendar))
        _preferredDayOfMonth = State(initialValue: calendar.component(.day, from: initialDate))
    }
    
    // Jours de la semaine alignés sur la même grille que les dates.
    private var weekDaySymbols: [String] {
        CalendarGridLayout.weekdaySymbols(for: calendar)
    }
    
    // MARK: - Computed Properties
    private var isSelectedDateToday: Bool {
        calendar.isDateInToday(selectedDate)
    }
    
    private var isDisplayedMonthCurrent: Bool {
        calendar.isDate(displayDate, equalTo: Date(), toGranularity: .month)
    }

    private var visibleMonthSlots: [CalendarMonthSlot] {
        CalendarGridLayout.monthSlots(for: displayDate, calendar: calendar)
    }

    private var visibleWeekDates: [Date] {
        CalendarGridLayout.weekDates(for: displayDate, calendar: calendar)
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
                // En-tête du calendrier
                calendarHeader
                
                // Mode de vue (mois/semaine)
                HStack(spacing: DS.Spacing.sm) {
                    Picker("Mode", selection: $calendarViewMode) {
                        Text("calendar.mode.month".localized).tag(CalendarViewMode.month)
                        Text("calendar.mode.week".localized).tag(CalendarViewMode.week)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: calendarViewMode) { _, newMode in
                        withAnimation(DS.Animation.navigation) {
                            slideDirection = .none
                            displayDate = displayDate(for: selectedDate, mode: newMode)
                        }
                    }
                    
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                
                // Ligne des jours de la semaine
                weekdayHeader
                
                // Affichage du calendrier selon le mode
                ZStack {
                    // Le calendrier est toujours présent — le loader s'affiche en overlay
                    // pour éviter le flash (calendrier → vide → calendrier) lors de la navigation.
                    if calendarViewMode == .month {
                        monthCalendarView
                            .transition(slideTransition(for: slideDirection))
                    } else {
                        weekCalendarView
                            .transition(slideTransition(for: slideDirection))
                    }

                    if isFiltering {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.ultraThinMaterial.opacity(0.5))
                            .transition(.opacity)
                    }
                }
                .offset(x: dragOffset)
                .clipped()
                .animation(.spring(response: 0.3, dampingFraction: 0.86), value: displayDate)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            // Feedback live : le calendrier suit le doigt à 25%
                            dragOffset = value.translation.width * 0.25
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            let velocity = value.predictedEndTranslation.width

                            if value.translation.width > threshold || velocity > 500 {
                                // Swipe droite → mois/semaine précédent
                                dragOffset = 0
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                                    slideDirection = .right
                                    if calendarViewMode == .month { shiftMonth(by: -1) }
                                    else { shiftWeek(by: -1) }
                                }
                            } else if value.translation.width < -threshold || velocity < -500 {
                                // Swipe gauche → mois/semaine suivant
                                dragOffset = 0
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                                    slideDirection = .left
                                    if calendarViewMode == .month { shiftMonth(by: 1) }
                                    else { shiftWeek(by: 1) }
                                }
                            } else {
                                // Seuil non atteint : retour élastique
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
                
                Spacer(minLength: 0)
                
                // Détails de la journée sélectionnée
                if let workDay = selectedWorkDay {
                    workDayDetailCard(workDay)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .dsScreenBackground(.purple)
            .overlay(alignment: .bottomLeading) {
                // Bouton « Aujourd'hui » flottant, façon Calendrier Apple
                if !isSelectedDateToday && selectedWorkDay == nil {
                    Button(action: goToToday) {
                        Text("calendar.today".localized)
                            .fontWeight(.semibold)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.md)
                    }
                    .buttonStyle(.glass)
                    .clipShape(Capsule())
                    .padding(.leading, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.sm)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("accessibility.today".localized)
                }
            }
            .navigationTitle("calendar.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: calendarViewMode)
            .sensoryFeedback(.selection, trigger: selectedDate)
            .onAppear {
                Analytics.shared.logScreenView("calendar")
                applyFocusedDateIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        showingDatePicker = true
                    }) {
                        Image(systemName: "calendar")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("calendar.selectDate".localized)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showingAddWorkDay = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("action.add".localized)
                    .popoverTip(addWorkDayTip, arrowEdge: .top)
                }
            }
            .sheet(isPresented: $showingAddWorkDay, onDismiss: {
                calendarDataRevision += 1
            }) {
                NavigationStack {
                    AddEditWorkDayView(workDay: WorkDay(date: calendar.startOfDay(for: selectedDate)))
                }
            }
            .sheet(isPresented: $showingEditSheet, onDismiss: {
                calendarDataRevision += 1
            }) {
                if let workDay = selectedWorkDay {
                    NavigationStack {
                        AddEditWorkDayView(workDay: workDay)
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(
                    initialDate: selectedDate
                ) { date in
                    let normalizedDate = calendar.startOfDay(for: date)
                    withAnimation(DS.Animation.navigation) {
                        selectDate(normalizedDate)
                        displayDate = displayDate(for: normalizedDate, mode: calendarViewMode)
                        slideDirection = .none
                    }
                }
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                let normalizedDate = calendar.startOfDay(for: newValue)

                if normalizedDate != newValue {
                    selectedDate = normalizedDate
                    return
                }

                let shouldUpdateDisplayDate: Bool
                if calendarViewMode == .month {
                    shouldUpdateDisplayDate = !calendar.isDate(oldValue, equalTo: newValue, toGranularity: .month)
                } else {
                    shouldUpdateDisplayDate = !visibleWeekDates.contains { calendar.isDate($0, inSameDayAs: normalizedDate) }
                }

                if shouldUpdateDisplayDate {
                    withAnimation(DS.Animation.navigation) {
                        displayDate = displayDate(for: normalizedDate, mode: calendarViewMode)
                        slideDirection = .none
                    }
                }
                
                // Chercher un WorkDay pour la date sélectionnée
                selectedWorkDay = findWorkDay(for: normalizedDate)
            }
            .onChange(of: focusedDate) { _, _ in
                applyFocusedDateIfNeeded()
            }
            .task(id: CalendarLoadIdentity(
                displayDate: displayDate,
                mode: calendarViewMode,
                dataRevision: calendarDataRevision
            )) {
                await updateDisplayedWorkDays()
            }
            .withErrorHandling()
    }

    // MARK: - Composants d'interface
    
    // En-tête avec navigation du calendrier
    private var calendarHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            // Grand titre aligné à gauche, façon Calendrier Apple
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                if calendarViewMode == .month {
                    Text(monthTitle)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .matchedGeometryEffect(id: "monthTitle", in: monthTransition)
                } else {
                    Text(weekRange)
                        .font(.title2)
                        .fontWeight(.bold)
                        .matchedGeometryEffect(id: "weekTitle", in: monthTransition)
                }

                Text(displayDate.formatted(.dateTime.year()))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .contentTransition(.numericText())

            Spacer()

            HStack(spacing: DS.Spacing.sm) {
                Button(action: {
                    withAnimation(DS.Animation.navigation) {
                        slideDirection = .right
                        if calendarViewMode == .month {
                            shiftMonth(by: -1)
                        } else {
                            shiftWeek(by: -1)
                        }
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.glass)
                .accessibilityLabel("accessibility.previousMonth".localized)

                Button(action: {
                    withAnimation(DS.Animation.navigation) {
                        slideDirection = .left
                        if calendarViewMode == .month {
                            shiftMonth(by: 1)
                        } else {
                            shiftWeek(by: 1)
                        }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .fontWeight(.semibold)
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.glass)
                .accessibilityLabel("accessibility.nextMonth".localized)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    /// Nom du mois seul, capitalisé (« Juin »), façon Calendrier Apple.
    private var monthTitle: String {
        displayDate.formatted(.dateTime.month(.wide)).capitalized
    }

    // En-tête des jours de la semaine — 1 lettre, week-ends grisés (façon Calendrier Apple)
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekDaySymbols.enumerated()), id: \.offset) { index, symbol in
                Text(String(symbol.prefix(1)).uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(index >= 5 ? .tertiary : .secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // Vue du calendrier mensuel — lignes de semaine séparées par un filet (façon Calendrier Apple)
    private var monthCalendarView: some View {
        VStack(spacing: 0) {
            ForEach(Array(stride(from: 0, to: visibleMonthSlots.count, by: 7)), id: \.self) { weekStart in
                if weekStart > 0 {
                    Divider()
                }

                HStack(spacing: 0) {
                    ForEach(visibleMonthSlots[weekStart..<min(weekStart + 7, visibleMonthSlots.count)]) { slot in
                        if let date = slot.date {
                            let workDay = findWorkDay(for: date)
                            Button {
                                withAnimation(DS.Animation.micro) {
                                    selectDate(date, workDay: workDay)
                                }
                            } label: {
                                ImprovedCalendarCell(
                                    date: date,
                                    workDay: workDay,
                                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                    isToday: calendar.isDateInToday(date),
                                    isWeekend: calendar.isDateInWeekend(date)
                                )
                            }
                            .buttonStyle(.plain)
                            .id(slot.id)
                            .accessibilityIdentifier("calendar-day-\(CalendarGridLayout.dateIdentity(for: date, calendar: calendar))")
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(accessibilityLabel(for: date, workDay: workDay))
                            .accessibilityAddTraits(calendar.isDate(date, inSameDayAs: selectedDate) ? [.isButton, .isSelected] : .isButton)
                            .accessibilityAction {
                                withAnimation(DS.Animation.micro) {
                                    selectDate(date, workDay: workDay)
                                }
                            }
                        } else {
                            // Cellule vide
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .id(slot.id)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .id("month-\(CalendarGridLayout.dateIdentity(for: displayDate, calendar: calendar))")
    }
    
    // Vue du calendrier hebdomadaire - version optimisée
    private var weekCalendarView: some View {
        VStack(spacing: 10) {
            // Jours de la semaine avec leur date
            HStack(spacing: 0) {
                ForEach(visibleWeekDates.indices, id: \.self) { index in
                    let date = visibleWeekDates[index]
                    let workDay = findWorkDay(for: date)
                    VStack(spacing: 8) {
                        // Jour de la semaine
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // Numéro du jour dans un cercle
                        ZStack {
                            Circle()
                                .fill(getDateBackgroundColor(date))
                                .frame(width: 36, height: 36)
                            
                            Text(String(calendar.component(.day, from: date)))
                                .fontWeight(calendar.isDateInToday(date) ? .bold : .regular)
                                .foregroundStyle(
                                    calendar.isDate(date, inSameDayAs: selectedDate) ? Color.white :
                                        calendar.isDateInToday(date) ? Color.blue : Color.primary
                                )
                        }
                        
                        // Indicateur de type de journée
                        if let workDay = workDay {
                            Image(systemName: workDay.type.icon)
                                .font(.caption)
                                .foregroundStyle(workDay.type.color)
                        } else {
                            Spacer()
                                .frame(height: 16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(DS.Animation.micro) {
                            selectDate(date, workDay: findWorkDay(for: date))
                        }
                    }
                    .accessibilityIdentifier("calendar-day-\(dateIdentity(for: date))")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityLabel(for: date, workDay: workDay))
                    .accessibilityAddTraits(calendar.isDate(date, inSameDayAs: selectedDate) ? [.isButton, .isSelected] : .isButton)
                    .accessibilityAction {
                        withAnimation(DS.Animation.micro) {
                            selectDate(date, workDay: workDay)
                        }
                    }
                }
            }
            .padding(.horizontal)

            // Conteneur d'événements pour la semaine
            weekEventsContainer
        }
        .padding(.top, 4)
        .id("week-\(weekIdentifier(for: displayDate))")
    }
    
    // Conteneur des événements de la semaine
    private var weekEventsContainer: some View {
        VStack(spacing: 12) {
            // Utilisation d'un composant de vue optimisé pour les événements de la semaine
            OptimizedWeekEvents(
                weekDates: visibleWeekDates,
                workDaysByDate: workDaysByDate,
                selectedDate: $selectedDate,
                selectedWorkDay: $selectedWorkDay
            )
        }
        .padding(.horizontal)
    }
    
    // Carte de détail de la journée sélectionnée
    private func workDayDetailCard(_ workDay: WorkDay) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(formatDate(workDay.date))
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(DS.Animation.interactive) { selectedWorkDay = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            }
            .padding(.horizontal)

            Divider()

            CalendarDetailRow(workDay: workDay)
                .contentShape(Rectangle())
                .onTapGesture { showingEditSheet = true }
                .contextMenu {
                    Button(role: .destructive) {
                        withAnimation(DS.Animation.interactive) { deleteWorkDay(workDay) }
                    } label: {
                        Label("action.delete".localized, systemImage: "trash")
                    }
                }
                .padding(.vertical, DS.Spacing.xs)

            HStack(spacing: DS.Spacing.sm) {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("action.edit".localized, systemImage: "pencil")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                        .padding(.vertical, DS.Spacing.sm)
                        .padding(.horizontal, DS.Spacing.md)
                        .dsGlassSurface(cornerRadius: DS.Radius.medium, interactive: true)
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(DS.Animation.interactive) { deleteWorkDay(workDay) }
                } label: {
                    Label("action.delete".localized, systemImage: "trash")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                        .padding(.vertical, DS.Spacing.sm)
                        .padding(.horizontal, DS.Spacing.md)
                        .dsGlassSurface(cornerRadius: DS.Radius.medium, interactive: true)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, DS.Spacing.sm)
        }
        .padding(.vertical, DS.Spacing.sm)
        .dsGlassSurface(cornerRadius: DS.Radius.card)
        .padding(.horizontal)
        .padding(.bottom, DS.Spacing.sm)
    }
    
    // MARK: - Transitions

    private func slideTransition(for direction: SlideDirection) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: direction == .right ? .leading : .trailing)
                .combined(with: .opacity),
            removal: .move(edge: direction == .right ? .trailing : .leading)
                .combined(with: .opacity)
        )
    }

    // MARK: - Méthodes d'optimisation

    // ✅ FetchDescriptor ciblé sur la période visible.
    @MainActor
    private func updateDisplayedWorkDays() async {
        isFiltering = true
        defer { isFiltering = false }

        let currentMode = calendarViewMode
        let currentDisplayDate = calendar.startOfDay(for: displayDate)
        let currentDataRevision = calendarDataRevision
        let currentWeekDates = CalendarGridLayout.weekDates(for: currentDisplayDate, calendar: calendar)

        // ✅ Fetch ciblé avec prédicat SQL — ne charge QUE les jours de la période visible
        var relevantWorkDays: [WorkDay] = []
        do {
            if currentMode == .month,
               let interval = calendar.dateInterval(of: .month, for: currentDisplayDate) {
                let start = interval.start
                let end   = interval.end
                var descriptor = FetchDescriptor<WorkDay>(
                    predicate: #Predicate<WorkDay> {
                        $0.date >= start &&
                        $0.date < end &&
                        !$0.isDeleted
                    },
                    sortBy: [SortDescriptor(\.date)]
                )
                descriptor.propertiesToFetch = [
                    \.id, \.date, \.typeRawValue, \.totalHours,
                    \.overtimeSeconds, \.bonusAmount, \.note,
                    \.startTime, \.endTime, \.isDeleted, \.modifiedAt
                ]
                relevantWorkDays = try modelContext.fetch(descriptor)

            } else if currentMode == .week,
                      let firstDay = currentWeekDates.first,
                      let lastDay = currentWeekDates.last,
                      let end = calendar.date(byAdding: .day, value: 1, to: lastDay) {
                var descriptor = FetchDescriptor<WorkDay>(
                    predicate: #Predicate<WorkDay> {
                        $0.date >= firstDay &&
                        $0.date < end &&
                        !$0.isDeleted
                    },
                    sortBy: [SortDescriptor(\.date)]
                )
                descriptor.propertiesToFetch = [
                    \.id, \.date, \.typeRawValue, \.totalHours,
                    \.overtimeSeconds, \.bonusAmount, \.note,
                    \.startTime, \.endTime, \.isDeleted, \.modifiedAt
                ]
                relevantWorkDays = try modelContext.fetch(descriptor)
            }
        } catch {
            AppLogger.error("Calendar fetch failed", category: AppLogger.general, error: error)
        }

        // Pré-construire le dictionnaire pour lookup O(1) au lieu de O(n) par cellule
        var lookup: [Date: WorkDay] = [:]
        for wd in relevantWorkDays {
            let key = calendar.startOfDay(for: wd.date)
            lookup[key] = wd
        }

        guard !Task.isCancelled,
              currentMode == calendarViewMode,
              currentDataRevision == calendarDataRevision,
              calendar.isDate(currentDisplayDate, inSameDayAs: displayDate)
        else { return }

        workDaysByDate = lookup
        selectedWorkDay = findWorkDay(for: selectedDate)
    }
    
    /// Génère un identifiant unique pour une semaine
    private func weekIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)"
    }
    
    /// Navigation vers le mois précédent ou suivant
    private func shiftMonth(by offset: Int) {
        if let navigation = CalendarGridLayout.monthNavigation(
            from: displayDate,
            preferredDay: preferredDayOfMonth,
            by: offset,
            calendar: calendar
        ) {
            displayDate = navigation.displayDate
            selectDate(navigation.selectedDate, updatePreferredDay: false)
        }
    }
    
    /// Navigation vers la semaine précédente ou suivante
    private func shiftWeek(by offset: Int) {
        let selectedWeekIndex = visibleWeekDates.firstIndex {
            calendar.isDate($0, inSameDayAs: selectedDate)
        } ?? 0

        if let rawNewDate = calendar.date(byAdding: .weekOfYear, value: offset, to: displayDate) {
            let newDate = calendar.startOfDay(for: rawNewDate)
            displayDate = newDate
            
            // Si la date sélectionnée n'est pas dans la nouvelle semaine, la réinitialiser
            let weekDates = CalendarGridLayout.weekDates(for: newDate, calendar: calendar)
            guard let firstDay = weekDates.first, let lastDay = weekDates.last else { return }
            let selectedDay = calendar.startOfDay(for: selectedDate)

            if selectedDay < firstDay || selectedDay > lastDay {
                // Sélectionner le même jour de la semaine dans la nouvelle semaine
                let clampedIndex = min(selectedWeekIndex, weekDates.count - 1)
                if weekDates.indices.contains(clampedIndex) {
                    selectDate(weekDates[clampedIndex])
                }
            }
        }
    }
    
    /// Met la date sélectionnée à aujourd'hui
    private func goToToday() {
        withAnimation(DS.Animation.appear) {
            let today = calendar.startOfDay(for: Date())
            selectDate(today)
            displayDate = displayDate(for: today, mode: calendarViewMode)
            slideDirection = .none
        }
        
    }

    private func applyFocusedDateIfNeeded() {
        guard let focusedDate else { return }

        let normalizedDate = calendar.startOfDay(for: focusedDate)
        withAnimation(DS.Animation.navigation) {
            calendarViewMode = .month
            selectDate(normalizedDate)
            displayDate = displayDate(for: normalizedDate, mode: .month)
            slideDirection = .none
            dragOffset = 0
        }
        self.focusedDate = nil
    }
    
    /// Supprime un WorkDay
    private func deleteWorkDay(_ workDay: WorkDay) {
        StatsCache.shared.onWorkDayDeleted(workDay)
        modelContext.delete(workDay)

        do {
            try modelContext.save()
            SiriSummaryCacheService(calendar: calendar).refresh(using: modelContext)
            if selectedWorkDay?.id == workDay.id { selectedWorkDay = nil }
            let key = calendar.startOfDay(for: workDay.date)
            if workDaysByDate[key]?.id == workDay.id {
                var next = workDaysByDate
                next.removeValue(forKey: key)
                workDaysByDate = next
            }
        } catch {
            ErrorManager.shared.handle(error, context: "CalendarDeleteWorkDay")
        }
    }
    
    /// Trouve le WorkDay correspondant à une date via le dictionnaire pré-calculé (O(1))
    private func findWorkDay(for date: Date) -> WorkDay? {
        workDaysByDate[calendar.startOfDay(for: date)]
    }

    private func selectDate(_ date: Date, workDay: WorkDay? = nil, updatePreferredDay: Bool = true) {
        let normalizedDate = calendar.startOfDay(for: date)
        selectedDate = normalizedDate
        if updatePreferredDay {
            preferredDayOfMonth = calendar.component(.day, from: normalizedDate)
        }
        selectedWorkDay = workDay ?? findWorkDay(for: normalizedDate)
    }

    private func dateIdentity(for date: Date) -> String {
        CalendarGridLayout.dateIdentity(for: date, calendar: calendar)
    }

    private func displayDate(for date: Date, mode: CalendarViewMode) -> Date {
        switch mode {
        case .month:
            return CalendarGridLayout.monthDisplayDate(for: date, calendar: calendar)
        case .week:
            return calendar.startOfDay(for: date)
        }
    }

    private func accessibilityLabel(for date: Date, workDay: WorkDay?) -> String {
        var parts = [date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())]

        if calendar.isDateInToday(date) {
            parts.append("calendar.today".localized)
        }

        if let workDay {
            parts.append(workDay.type.localizedName)
        }

        return parts.joined(separator: ", ")
    }
    
    /// Formatte une date en chaîne localisée
    private func formatDate(_ date: Date) -> String {
        Self.fullDateFormatter.string(from: date).capitalized
    }
    
    /// Retourne la couleur de fond pour une date dans la vue semaine
    private func getDateBackgroundColor(_ date: Date) -> Color {
        if calendar.isDate(date, inSameDayAs: selectedDate) {
            return .blue
        } else if calendar.isDateInToday(date) {
            return .blue.opacity(0.2)
        } else if findWorkDay(for: date) != nil {
            return Color(.systemGray5)
        } else {
            return Color(.systemGray6)
        }
    }
    
    // MARK: - DateFormatters statiques (créés une seule fois)
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f
    }()

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateStyle = .full
        return f
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = "d MMM"
        return f
    }()

    private static let dayOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.dateFormat = "d"
        return f
    }()

    // Formats et textes
    private var monthAndYear: String {
        Self.monthYearFormatter.string(from: displayDate).lowercased()
    }

    private var weekRange: String {
        guard let firstDay = visibleWeekDates.first, let lastDay = visibleWeekDates.last else {
            return ""
        }

        if calendar.isDate(firstDay, equalTo: lastDay, toGranularity: .month) {
            return "\(Self.dayOnlyFormatter.string(from: firstDay)) - \(lastDay.formatted(.dateTime.day().month(.abbreviated)))"
        }

        return "\(Self.dayMonthFormatter.string(from: firstDay)) - \(Self.dayMonthFormatter.string(from: lastDay))"
    }
}

// Vue optimisée pour afficher les événements d'une semaine
struct OptimizedWeekEvents: View {
    let weekDates: [Date]
    let workDaysByDate: [Date: WorkDay]
    @Binding var selectedDate: Date
    @Binding var selectedWorkDay: WorkDay?

    private let calendar = CalendarGridLayout.displayCalendar

    private var hasEvents: Bool {
        !workDaysByDate.isEmpty
    }
    
    var body: some View {
        if hasEvents {
            ForEach(weekDates, id: \.self) { date in
                if let workDay = workDaysByDate[calendar.startOfDay(for: date)] {
                    WeekDayEventRow(
                        workDay: workDay,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(DS.Animation.micro) {
                            selectedDate = calendar.startOfDay(for: date)
                            selectedWorkDay = workDay
                        }
                    }
                    .transition(.opacity)
                    .id("event-\(workDay.id)")
                }
            }
        } else {
            // Message si aucun événement dans la semaine
            VStack(spacing: 16) {
                Image(systemName: "calendar.badge.plus")
                    .font(.largeTitle)
                    .foregroundStyle(.blue.opacity(0.7))
                
                Text("calendar.noEvents".localized)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
            .padding(.vertical, 20)
        }
    }
}

// MARK: - Sous-vue : Ligne de détail d'une journée
struct CalendarDetailRow: View {
    let workDay: WorkDay
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            
            // Section gauche avec type et heures
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: workDay.type.icon)
                        .foregroundStyle(workDay.type.color)
                    Text(workDay.type.localizedName)
                        .font(.headline)
                }
                
                if workDay.type == .work {
                    Text(workDay.formattedTotalHours)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Note si présente
            if let note = workDay.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.blue)
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
                            .foregroundStyle(
                                workDay.overtimeSeconds > 0 ? .green : .red
                            )
                    }
                    
                    if workDay.bonusAmount > 0 {
                        Text("Bonus: \(workDay.bonusAmount, specifier: "%.0f")")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Sous-vues améliorées

/// Cellule de calendrier améliorée avec design Liquid Glass
struct ImprovedCalendarCell: View {
    let date: Date
    let workDay: WorkDay?
    let isSelected: Bool
    let isToday: Bool
    var isWeekend: Bool = false

    @Environment(\.colorScheme) var colorScheme
    private let calendar = CalendarGridLayout.displayCalendar

    var body: some View {
        VStack(spacing: 3) {
            // Numéro du jour dans un cercle (visible uniquement si sélectionné/aujourd'hui)
            ZStack {
                if isSelected {
                    Circle()
                        .fill(isToday ? Color.blue : Color.secondary.opacity(0.35))
                        .transition(.scale.combined(with: .opacity))
                } else if isToday {
                    Circle()
                        .fill(Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.12))
                }

                Text(String(calendar.component(.day, from: date)))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isToday || isSelected ? .semibold : .regular)
                    .monospacedDigit()
                    .foregroundStyle(textColor)
            }
            .frame(width: 34, height: 34)

            // Étiquette du type de journée, façon événement Calendrier Apple
            if let workDay {
                Text(workDay.type.localizedName)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(workDay.type.color)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity)
                    .background(
                        workDay.type.color.opacity(colorScheme == .dark ? 0.28 : 0.16),
                        in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                    )
                    .padding(.horizontal, 2)
            } else {
                Color.clear
                    .frame(height: 17)
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // Couleur du texte basée sur l'état
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .blue
        }
        return isWeekend ? .secondary : .primary
    }
}

/// Ligne d'événement pour la vue semaine
struct WeekDayEventRow: View {
    let workDay: WorkDay
    let isSelected: Bool
    
    var body: some View {
        HStack {
            // Barre verticale colorée
            Rectangle()
                .fill(workDay.type.color)
                .frame(width: 4)
                .cornerRadius(2)
            
            // Contenu principal
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: workDay.type.icon)
                        .foregroundStyle(workDay.type.color)
                    
                    Text(workDay.type.localizedName)
                        .font(.headline)
                    
                    Spacer()
                    
                    if workDay.type == .work {
                        Text(workDay.formattedTotalHours)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let note = workDay.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                if workDay.type == .work {
                    HStack {
                        if workDay.overtimeSeconds != 0 {
                            Label(
                                workDay.formattedOvertimeHours,
                                systemImage: workDay.overtimeSeconds > 0 ? "arrow.up.circle" : "arrow.down.circle"
                            )
                            .font(.caption)
                            .foregroundStyle(workDay.overtimeSeconds > 0 ? .green : .red)
                        }
                        
                        if workDay.bonusAmount > 0 {
                            Spacer()
                            
                            Label(
                                String(format: "+%.0f", workDay.bonusAmount),
                                systemImage: "dollarsign.circle"
                            )
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? workDay.type.color.opacity(0.14) : Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected ? workDay.type.color : Color(.separator).opacity(0.16),
                            lineWidth: 1
                        )
                )
        )
        .animation(DS.Animation.micro, value: isSelected)
    }
}

/// Feuille modale de sélection de date
struct DatePickerSheet: View {
    let onConfirm: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftDate: Date

    init(initialDate: Date, onConfirm: @escaping (Date) -> Void) {
        self.onConfirm = onConfirm
        _draftDate = State(initialValue: CalendarGridLayout.displayCalendar.startOfDay(for: initialDate))
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "calendar.selectDate".localized,
                    selection: $draftDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Button(action: {
                    onConfirm(CalendarGridLayout.displayCalendar.startOfDay(for: draftDate))
                    dismiss()
                }) {
                    Text("action.confirm".localized)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.glassProminent)
                .padding()
            }
            .navigationTitle("calendar.selectDate".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("action.close".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Preview
#Preview {
    NavigationStack {
        CalendarView()
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}
