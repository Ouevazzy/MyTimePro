import SwiftUI
import SwiftData
import TipKit

enum CalendarViewMode: Hashable {
    case year
    case month
    case week
}

enum CalendarEventDisplayMode: String, CaseIterable, Hashable {
    case compact
    case stack
    case details

    var title: String {
        switch self {
        case .compact: return "calendar.view.compact".localized
        case .stack: return "calendar.view.stack".localized
        case .details: return "calendar.view.details".localized
        }
    }
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

    // ✅ Memoïsation des grilles de mois : les slots d'un mois sont immuables,
    // inutile de refaire les calculs Calendar (~35 cellules) à chaque render.
    @MainActor private static var slotsCache: [Date: [CalendarMonthSlot]] = [:]

    @MainActor
    static func cachedMonthSlots(for date: Date, calendar: Calendar) -> [CalendarMonthSlot] {
        let month = monthDisplayDate(for: date, calendar: calendar)
        if let cached = slotsCache[month] {
            return cached
        }
        let slots = monthSlots(for: month, calendar: calendar)
        slotsCache[month] = slots
        return slots
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding private var focusedDate: Date?

    // État principal
    @State private var selectedDate: Date
    @State private var displayDate: Date
    @State private var calendarViewMode: CalendarViewMode = .month
    @State private var calendarDataRevision = 0
    @State private var preferredDayOfMonth: Int

    // Gestion des feuilles modales
    @State private var showingAddWorkDay = false
    // ✅ .sheet(item:) : le WorkDay à éditer est capturé au moment du tap,
    // plus de risque de feuille vide si selectedWorkDay change entre-temps.
    @State private var editingWorkDay: WorkDay?
    @State private var selectedWorkDay: WorkDay?
    @State private var workDayPendingDeletion: WorkDay?
    @State private var showingDatePicker = false
    
    // Animation du mois
    @State private var slideDirection: SlideDirection = .none
    @State private var dragOffset: CGFloat = 0

    // Nouvelles optimisations
    @State private var workDaysByDate: [Date: [WorkDay]] = [:]  // Lookup O(1), plusieurs entrées par date
    // ✅ Version des données : les MonthSectionView (Equatable) ne se re-rendent
    // que quand cette valeur change, pas à chaque réévaluation du body.
    @State private var workDaysVersion = 0
    @State private var isFiltering = false
    // ✅ Période déjà chargée : évite un re-fetch SwiftData à chaque mois scrollé
    @State private var loadedInterval: DateInterval?
    @State private var loadedRevision = -1

    // Scroll vertical continu entre les mois (façon Calendrier Apple)
    @State private var scrolledMonth: Date?
    @AppStorage("calendar.showWeekNumbers") private var showWeekNumbers = false
    @AppStorage("calendar.eventDisplayMode") private var eventDisplayMode: CalendarEventDisplayMode = .compact
    
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
        _scrolledMonth = State(initialValue: CalendarGridLayout.monthDisplayDate(for: initialDate, calendar: calendar))
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
            calendarTopBar
            calendarModePicker

            if calendarViewMode == .month {
                weekdayHeader
            }

            ZStack {
                Group {
                    switch calendarViewMode {
                    case .year:
                        yearCalendarView
                            .transition(.scale(scale: 0.94).combined(with: .opacity))
                    case .month:
                        monthCalendarView
                            .transition(.scale(scale: 1.04).combined(with: .opacity))
                    case .week:
                        dayCalendarView
                            .transition(slideTransition(for: slideDirection))
                            .offset(x: dragOffset)
                    }
                }
                .animation(.spring(response: 0.34, dampingFraction: 0.88), value: calendarViewMode)

                if isFiltering && workDaysByDate.isEmpty && calendarViewMode != .year {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial.opacity(0.5))
                        .transition(.opacity)
                }
            }
            .simultaneousGesture(
                MagnifyGesture()
                    .onEnded { value in
                        withAnimation(DS.Animation.navigation) {
                            switch (calendarViewMode, value.magnification) {
                            case (.year, 1.15...):
                                openMonth(displayDate)
                            case (.month, ..<0.85):
                                openYearOverview()
                            case (.month, 1.15...):
                                openDay(selectedDate)
                            case (.week, ..<0.85):
                                openMonth(selectedDate)
                            default:
                                break
                            }
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .dsScreenBackground(.purple)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if calendarViewMode == .month {
                CalendarSelectionPreview(date: selectedDate, entries: findWorkDays(for: selectedDate))
                    .padding(.horizontal)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(Color(.systemGroupedBackground))
            }
        }
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(.selection, trigger: calendarViewMode)
            .sensoryFeedback(.selection, trigger: selectedDate)
            // Léger retour haptique quand un nouveau mois devient visible (façon Calendrier Apple)
            .sensoryFeedback(.impact(weight: .light), trigger: displayDate)
            .onAppear {
                Analytics.shared.logScreenView("calendar")
                applyFocusedDateIfNeeded()
            }
            .sheet(isPresented: $showingAddWorkDay, onDismiss: {
                calendarDataRevision += 1
            }) {
                NavigationStack {
                    AddEditWorkDayView(workDay: WorkDay(date: calendar.startOfDay(for: selectedDate)))
                }
            }
            .sheet(item: $editingWorkDay, onDismiss: {
                calendarDataRevision += 1
            }) { workDay in
                NavigationStack {
                    AddEditWorkDayView(workDay: workDay)
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
            .confirmationDialog(
                "calendar.delete.title".localized,
                isPresented: Binding(
                    get: { workDayPendingDeletion != nil },
                    set: { if !$0 { workDayPendingDeletion = nil } }
                ),
                presenting: workDayPendingDeletion
            ) { workDay in
                Button("action.delete".localized, role: .destructive) {
                    withAnimation(DS.Animation.interactive) {
                        deleteWorkDay(workDay)
                    }
                    workDayPendingDeletion = nil
                }
                Button("action.cancel".localized, role: .cancel) {
                    workDayPendingDeletion = nil
                }
            } message: { _ in
                Text("calendar.delete.message".localized)
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                let normalizedDate = calendar.startOfDay(for: newValue)

                if normalizedDate != newValue {
                    selectedDate = normalizedDate
                    return
                }

                let shouldUpdateDisplayDate: Bool
                if calendarViewMode == .year {
                    shouldUpdateDisplayDate = false
                } else if calendarViewMode == .month {
                    shouldUpdateDisplayDate = !calendar.isDate(oldValue, equalTo: newValue, toGranularity: .month)
                } else {
                    shouldUpdateDisplayDate = !calendar.isDate(oldValue, inSameDayAs: normalizedDate)
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

    private var calendarTopBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            leadingCalendarControl
            Spacer(minLength: DS.Spacing.sm)
            calendarViewMenu
            calendarAddButton
        }
        .padding(.horizontal)
        .padding(.vertical, DS.Spacing.xs)
    }

    private var calendarAddButton: some View {
        Button(action: beginAddingWorkDay) {
            Image(systemName: "plus")
                .font(.title3.weight(.medium))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("action.add".localized)
        .accessibilityIdentifier("calendar.add")
        .popoverTip(addWorkDayTip, arrowEdge: .top)
    }

    private var calendarModePicker: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    viewModePicker
                    todayButton
                }
            } else {
                HStack(spacing: DS.Spacing.sm) {
                    viewModePicker
                    todayButton
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, DS.Spacing.xs)
    }

    private var viewModePicker: some View {
        Picker("calendar.mode.label".localized, selection: Binding(
            get: { calendarViewMode },
            set: { mode in
                switch mode {
                case .year: openYearOverview()
                case .month: openMonth(selectedDate)
                case .week: openDay(selectedDate)
                }
            }
        )) {
            Text("calendar.mode.year".localized).tag(CalendarViewMode.year)
            Text("calendar.mode.month".localized).tag(CalendarViewMode.month)
            Text("calendar.mode.day".localized).tag(CalendarViewMode.week)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("calendar.view-selector")
    }

    @ViewBuilder
    private var leadingCalendarControl: some View {
        switch calendarViewMode {
        case .year:
            Color.clear
                .frame(width: 1, height: 44)
                .accessibilityHidden(true)
        case .month:
            Button(action: openYearOverview) {
                Label(displayDate.formatted(.dateTime.year()), systemImage: "chevron.left")
                    .font(.headline)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("calendar.yearOverview".localized)
            .accessibilityIdentifier("calendar.year-overview")
        case .week:
            Button {
                openMonth(selectedDate)
            } label: {
                Label(selectedDate.formatted(.dateTime.month(.wide)).capitalized, systemImage: "chevron.left")
                    .font(.headline)
                    .padding(.horizontal, 4)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("calendar.backToMonth".localized)
            .accessibilityIdentifier("calendar.back-to-month")
        }
    }

    private var calendarViewMenu: some View {
        Menu {
            Button {
                showingDatePicker = true
            } label: {
                Label("calendar.selectDate".localized, systemImage: "calendar")
            }

            Toggle(isOn: $showWeekNumbers) {
                Label("calendar.weekNumbers".localized, systemImage: "number")
            }

            Picker("calendar.view.label".localized, selection: $eventDisplayMode) {
                ForEach(CalendarEventDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.title3)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("calendar.options".localized)
        .accessibilityIdentifier("calendar.mode")
    }

    private var todayButton: some View {
        Button(action: goToToday) {
            Text("calendar.today".localized)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, DS.Spacing.xs)
                .frame(minHeight: 44)
                .fixedSize()
        }
        .buttonStyle(.glass)
        .accessibilityLabel("accessibility.today".localized)
        .accessibilityIdentifier("calendar.today")
    }

    // Abréviations localisées : mardi et mercredi restent distincts.
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            if showWeekNumbers && calendarViewMode == .month {
                Color.clear.frame(width: 22, height: 1)
            }

            ForEach(Array(weekDaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.secondaryText)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private static let continuousYearsCache: [Int] = {
        let currentYear = CalendarGridLayout.displayCalendar.component(.year, from: Date())
        return Array((currentYear - 10)...(currentYear + 10))
    }()

    private var yearCalendarView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DS.Spacing.xl) {
                    ForEach(Self.continuousYearsCache, id: \.self) { year in
                        YearSectionView(
                            year: year,
                            selectedDate: selectedDate,
                            today: calendar.startOfDay(for: Date()),
                            calendar: calendar,
                            onSelectMonth: openMonth(_:)
                        )
                        .id(year)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, DS.Spacing.md)
            }
            .scrollIndicators(.hidden)
            .task {
                try? await Task.sleep(for: .milliseconds(40))
                guard !Task.isCancelled else { return }
                proxy.scrollTo(calendar.component(.year, from: displayDate), anchor: .top)
            }
            .onChange(of: displayDate) { _, newValue in
                withAnimation(DS.Animation.navigation) {
                    proxy.scrollTo(calendar.component(.year, from: newValue), anchor: .top)
                }
            }
        }
        .accessibilityIdentifier("calendar.year-view")
    }
    
    /// Plage de mois pour le scroll continu : ±10 ans autour du mois courant.
    /// ✅ Calculée une seule fois (241 appels Calendar) au lieu de à chaque render.
    private static let continuousMonthsCache: [Date] = {
        let calendar = CalendarGridLayout.displayCalendar
        let base = CalendarGridLayout.monthDisplayDate(for: Date(), calendar: calendar)
        return (-120...120).compactMap { calendar.date(byAdding: .month, value: $0, to: base) }
    }()

    private var continuousMonths: [Date] { Self.continuousMonthsCache }

    // Vue du calendrier mensuel — scroll vertical continu entre les mois (façon Calendrier Apple)
    private var monthCalendarView: some View {
        let today = calendar.startOfDay(for: Date())

        return ScrollView {
            LazyVStack(spacing: DS.Spacing.md) {
                ForEach(continuousMonths, id: \.self) { month in
                    // ✅ Vue Equatable : un mois n'est re-rendu que si sa sélection,
                    // ses données ou ses réglages changent — pas à chaque tick de scroll.
                    MonthSectionView(
                        month: month,
                        slots: CalendarGridLayout.cachedMonthSlots(for: month, calendar: calendar),
                        selectedDate: calendar.isDate(selectedDate, equalTo: month, toGranularity: .month) ? selectedDate : nil,
                        today: today,
                        showWeekNumbers: showWeekNumbers,
                        eventDisplayMode: eventDisplayMode,
                        workDaysVersion: workDaysVersion,
                        calendar: calendar,
                        findWorkDays: findWorkDays(for:),
                        onSelect: { date, workDay in
                            withAnimation(DS.Animation.micro) {
                                selectDate(date, workDay: workDay)
                            }
                        },
                        onEdit: { workDay in
                            selectDate(workDay.date, workDay: workDay)
                            editingWorkDay = workDay
                        },
                        onDelete: { workDay in
                            workDayPendingDeletion = workDay
                        },
                        onAdd: { date in
                            selectDate(date)
                            showingAddWorkDay = true
                        }
                    )
                    .equatable()
                    .id(month)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrolledMonth, anchor: .top)
        .scrollIndicators(.hidden)
        .task {
            // Le positionnement initial de scrollPosition dérive avec des hauteurs
            // de sections variables : on re-cible le mois affiché après le premier layout.
            // ✅ .task est annulé automatiquement si la vue disparaît (vs asyncAfter).
            let target = CalendarGridLayout.monthDisplayDate(for: displayDate, calendar: calendar)
            scrolledMonth = nil
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            scrolledMonth = target
        }
        .onChange(of: scrolledMonth) { _, newValue in
            // Le mois visible en haut pilote le titre et le chargement des données
            guard let newValue,
                  !calendar.isDate(newValue, equalTo: displayDate, toGranularity: .month) else { return }
            displayDate = newValue
        }
        .onChange(of: displayDate) { _, newValue in
            // Navigation externe (chevrons, date picker, Siri, Aujourd'hui) → scroll
            guard calendarViewMode == .month else { return }
            let target = CalendarGridLayout.monthDisplayDate(for: newValue, calendar: calendar)
            guard scrolledMonth != target else { return }
            withAnimation(DS.Animation.navigation) { scrolledMonth = target }
        }
        .onScrollPhaseChange { _, newPhase in
            guard newPhase == .idle,
                  let scrolledMonth,
                  !calendar.isDate(selectedDate, equalTo: scrolledMonth, toGranularity: .month),
                  let navigation = CalendarGridLayout.monthNavigation(
                    from: scrolledMonth,
                    preferredDay: preferredDayOfMonth,
                    by: 0,
                    calendar: calendar
                  ) else { return }

            withAnimation(DS.Animation.micro) {
                selectDate(navigation.selectedDate, updatePreferredDay: false)
            }
        }
    }

    /// Vue Jour : bandeau hebdomadaire, puis véritable ligne horaire.
    private var dayCalendarView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(visibleWeekDates, id: \.self) { date in
                    let workDay = findWorkDay(for: date)
                    Button {
                        withAnimation(DS.Animation.micro) {
                            selectDate(date, workDay: workDay)
                            displayDate = date
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(calendar.isDateInWeekend(date) ? .tertiary : .secondary)

                            ZStack {
                                if calendar.isDate(date, inSameDayAs: selectedDate) {
                                    Circle().fill(Color.primary)
                                } else if calendar.isDateInToday(date) {
                                    Circle().fill(Color.blue)
                                }

                                Text(String(calendar.component(.day, from: date)))
                                    .font(.body.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(
                                        calendar.isDate(date, inSameDayAs: selectedDate)
                                            ? Color(.systemBackground)
                                            : calendar.isDateInToday(date) ? .white : .primary
                                    )
                            }
                            .frame(width: 36, height: 36)

                            Circle()
                                .fill(workDay?.type.color ?? .clear)
                                .frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("calendar-day-\(dateIdentity(for: date))")
                    .accessibilityLabel(accessibilityLabel(for: date, workDay: workDay))
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)

            Divider()

            HStack(alignment: .firstTextBaseline) {
                Text("S\(calendar.component(.weekOfYear, from: selectedDate))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatDate(selectedDate))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal)
            .padding(.vertical, DS.Spacing.sm)

            Divider()

            WorkDayTimelineView(
                date: selectedDate,
                workDays: findWorkDays(for: selectedDate),
                calendar: calendar,
                onAdd: beginAddingWorkDay,
                onEdit: { workDay in editingWorkDay = workDay },
                onDelete: { workDay in workDayPendingDeletion = workDay }
            )
        }
        .id("day-\(dateIdentity(for: selectedDate))")
        .accessibilityIdentifier("calendar.day-view")
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    dragOffset = value.translation.width * 0.18
                }
                .onEnded { value in
                    defer { dragOffset = 0 }
                    guard abs(value.translation.width) > abs(value.translation.height),
                          abs(value.translation.width) > 50 else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        slideDirection = value.translation.width > 0 ? .right : .left
                        shiftDay(by: value.translation.width > 0 ? -1 : 1)
                    }
                }
        )
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
        let currentMode = calendarViewMode
        let currentDisplayDate = calendar.startOfDay(for: displayDate)
        let currentDataRevision = calendarDataRevision
        let currentWeekDates = CalendarGridLayout.weekDates(for: currentDisplayDate, calendar: calendar)

        guard currentMode != .year else {
            isFiltering = false
            return
        }

        // ✅ Skip : la période visible (+1 mois de marge) est déjà couverte par le
        // dernier fetch (±2 mois) → pas de re-fetch à chaque mois scrollé.
        if currentDataRevision == loadedRevision,
           let loaded = loadedInterval,
           let needed = neededInterval(mode: currentMode, displayDate: currentDisplayDate, weekDates: currentWeekDates),
           loaded.start <= needed.start, loaded.end >= needed.end {
            return
        }

        isFiltering = true
        defer { isFiltering = false }

        // ✅ Fetch ciblé avec prédicat SQL — ne charge QUE les jours de la période visible
        var relevantWorkDays: [WorkDay] = []
        var fetchedInterval: DateInterval?
        do {
            if currentMode == .month,
               let interval = calendar.dateInterval(of: .month, for: currentDisplayDate),
               // Scroll continu : précharge ±2 mois autour du mois visible
               let start = calendar.date(byAdding: .month, value: -2, to: interval.start),
               let end = calendar.date(byAdding: .month, value: 2, to: interval.end) {
                fetchedInterval = DateInterval(start: start, end: end)
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
                fetchedInterval = DateInterval(start: firstDay, end: end)
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
        var lookup: [Date: [WorkDay]] = [:]
        for wd in relevantWorkDays {
            let key = calendar.startOfDay(for: wd.date)
            lookup[key, default: []].append(wd)
        }
        for key in lookup.keys {
            lookup[key]?.sort {
                ($0.startTime ?? $0.createdAt) < ($1.startTime ?? $1.createdAt)
            }
        }

        guard !Task.isCancelled,
              currentMode == calendarViewMode,
              currentDataRevision == calendarDataRevision,
              calendar.isDate(currentDisplayDate, inSameDayAs: displayDate)
        else { return }

        workDaysByDate = lookup
        workDaysVersion += 1
        loadedInterval = fetchedInterval
        loadedRevision = currentDataRevision
        selectedWorkDay = findWorkDay(for: selectedDate)
    }

    /// Période minimale que le cache doit couvrir pour éviter un re-fetch.
    private func neededInterval(mode: CalendarViewMode, displayDate: Date, weekDates: [Date]) -> DateInterval? {
        switch mode {
        case .year:
            return nil
        case .month:
            guard let interval = calendar.dateInterval(of: .month, for: displayDate),
                  let start = calendar.date(byAdding: .month, value: -1, to: interval.start),
                  let end = calendar.date(byAdding: .month, value: 1, to: interval.end) else {
                return nil
            }
            return DateInterval(start: start, end: end)
        case .week:
            guard let firstDay = weekDates.first,
                  let lastDay = weekDates.last,
                  let end = calendar.date(byAdding: .day, value: 1, to: lastDay) else {
                return nil
            }
            return DateInterval(start: firstDay, end: end)
        }
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

    private func shiftDay(by offset: Int) {
        guard let date = calendar.date(byAdding: .day, value: offset, to: selectedDate) else { return }
        openDay(date)
    }

    private func openYearOverview() {
        withAnimation(DS.Animation.navigation) {
            calendarViewMode = .year
            displayDate = displayDate(for: selectedDate, mode: .year)
            slideDirection = .none
            dragOffset = 0
        }
    }

    private func openMonth(_ month: Date) {
        let monthStart = CalendarGridLayout.monthDisplayDate(for: month, calendar: calendar)
        let targetDate: Date

        if calendar.isDate(selectedDate, equalTo: monthStart, toGranularity: .month) {
            targetDate = selectedDate
        } else if let navigation = CalendarGridLayout.monthNavigation(
            from: monthStart,
            preferredDay: preferredDayOfMonth,
            by: 0,
            calendar: calendar
        ) {
            targetDate = navigation.selectedDate
        } else {
            targetDate = monthStart
        }

        withAnimation(DS.Animation.navigation) {
            selectDate(targetDate, updatePreferredDay: false)
            displayDate = monthStart
            scrolledMonth = monthStart
            calendarViewMode = .month
            slideDirection = .none
            dragOffset = 0
        }
    }

    private func openDay(_ date: Date, workDay: WorkDay? = nil) {
        let normalizedDate = calendar.startOfDay(for: date)
        withAnimation(DS.Animation.navigation) {
            selectDate(normalizedDate, workDay: workDay)
            displayDate = normalizedDate
            calendarViewMode = .week
            slideDirection = .none
            dragOffset = 0
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

    /// Le bouton + suit toujours la période réellement visible. Après un scroll
    /// manuel, il ne peut donc plus créer par erreur une entrée dans l'ancien mois.
    private func beginAddingWorkDay() {
        let targetDate: Date
        switch calendarViewMode {
        case .year:
            let displayedYear = calendar.component(.year, from: displayDate)
            let currentYear = calendar.component(.year, from: Date())
            targetDate = displayedYear == currentYear
                ? calendar.startOfDay(for: Date())
                : (calendar.date(from: DateComponents(year: displayedYear, month: 1, day: 1)) ?? selectedDate)
        case .month:
            if calendar.isDate(selectedDate, equalTo: displayDate, toGranularity: .month) {
                targetDate = selectedDate
            } else if calendar.isDate(displayDate, equalTo: Date(), toGranularity: .month) {
                targetDate = calendar.startOfDay(for: Date())
            } else {
                targetDate = CalendarGridLayout.monthDisplayDate(for: displayDate, calendar: calendar)
            }
        case .week:
            targetDate = visibleWeekDates.contains { calendar.isDate($0, inSameDayAs: selectedDate) }
                ? selectedDate
                : (visibleWeekDates.first ?? displayDate)
        }

        selectDate(targetDate)
        showingAddWorkDay = true
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
        let affectedDate = workDay.date
        StatsCache.shared.onWorkDayDeleted(workDay)
        modelContext.delete(workDay)

        do {
            _ = try WorkDay.reconcileDailyOvertime(in: modelContext, for: [affectedDate], calendar: calendar)
            try modelContext.save()
            SiriSummaryCacheService(calendar: calendar).refresh(using: modelContext)
            let key = calendar.startOfDay(for: workDay.date)
            if workDaysByDate[key]?.contains(where: { $0.id == workDay.id }) == true {
                var next = workDaysByDate
                next[key]?.removeAll { $0.id == workDay.id }
                if next[key]?.isEmpty == true {
                    next.removeValue(forKey: key)
                }
                workDaysByDate = next
                if selectedWorkDay?.id == workDay.id {
                    selectedWorkDay = next[key]?.first
                }
                workDaysVersion += 1
            }
        } catch {
            modelContext.rollback()
            ErrorManager.shared.handle(error, context: "CalendarDeleteWorkDay")
        }
    }
    
    /// Trouve le WorkDay correspondant à une date via le dictionnaire pré-calculé (O(1))
    private func findWorkDay(for date: Date) -> WorkDay? {
        findWorkDays(for: date).first
    }

    private func findWorkDays(for date: Date) -> [WorkDay] {
        workDaysByDate[calendar.startOfDay(for: date), default: []]
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
        case .year:
            let year = calendar.component(.year, from: date)
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? date
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
        let value = Self.fullDateFormatter.string(from: date)
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
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
                        Label(
                            workDay.formattedOvertimeHours,
                            systemImage: workDay.overtimeSeconds > 0 ? "arrow.up" : "arrow.down"
                        )
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline)
                            .foregroundStyle(workDay.overtimeSeconds > 0 ? .green : .red)
                    }
                    
                    if workDay.bonusAmount > 0 {
                        Text("calendar.bonus".localized(workDay.bonusAmount))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Vue annuelle

private struct YearSectionView: View {
    let year: Int
    let selectedDate: Date
    let today: Date
    let calendar: Calendar
    let onSelectMonth: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    private var isCurrentYear: Bool {
        calendar.component(.year, from: today) == year
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(String(year))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(isCurrentYear ? Color.red : Color.primary)
                .contentTransition(.numericText())

            LazyVGrid(columns: columns, alignment: .leading, spacing: DS.Spacing.lg) {
                ForEach(1...12, id: \.self) { month in
                    if let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) {
                        Button {
                            onSelectMonth(date)
                        } label: {
                            MiniMonthView(
                                month: date,
                                selectedDate: selectedDate,
                                today: today,
                                calendar: calendar
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(date.formatted(.dateTime.month(.wide).year()))
                        .accessibilityHint("calendar.year.monthHint".localized)
                        .accessibilityIdentifier(
                            String(format: "calendar-month-%04d-%02d", year, month)
                        )
                    }
                }
            }
        }
        .accessibilityIdentifier("calendar-year-\(year)")
    }
}

private struct MiniMonthView: View {
    let month: Date
    let selectedDate: Date
    let today: Date
    let calendar: Calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(month.formatted(.dateTime.month(.wide)))
                .font(.headline)
                .foregroundStyle(isCurrentMonth ? Color.red : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(CalendarGridLayout.monthSlots(for: month, calendar: calendar)) { slot in
                    if let date = slot.date {
                        ZStack {
                            if calendar.isDate(date, inSameDayAs: today) {
                                Circle().fill(Color.red)
                            } else if calendar.isDate(date, inSameDayAs: selectedDate) {
                                Circle().stroke(Color.primary, lineWidth: 1)
                            }

                            Text(String(calendar.component(.day, from: date)))
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(
                                    calendar.isDate(date, inSameDayAs: today)
                                        ? Color.white
                                        : calendar.isDateInWeekend(date) ? .secondary : .primary
                                )
                        }
                        .frame(height: 13)
                    } else {
                        Color.clear.frame(height: 13)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: today, toGranularity: .month)
    }
}

// MARK: - Section de mois (scroll continu)

/// Un mois du scroll continu : titre inline + grille de semaines séparées par un filet.
/// ✅ Equatable : pendant le scroll (displayDate change) ou une sélection dans un
/// autre mois, `==` reste vrai et SwiftUI saute entièrement le re-rendu de la
/// section (~35 cellules avec contextMenu chacune). C'est ce qui rend le scroll
/// continu fluide, façon Calendrier Apple.
private struct MonthSectionView: View, Equatable {
    let month: Date
    let slots: [CalendarMonthSlot]
    /// Date sélectionnée si elle tombe dans ce mois, sinon nil.
    let selectedDate: Date?
    /// startOfDay du jour courant — passé en paramètre pour rester dans `==`.
    let today: Date
    let showWeekNumbers: Bool
    let eventDisplayMode: CalendarEventDisplayMode
    /// Incrémenté à chaque nouveau fetch : force le re-rendu quand les données changent.
    let workDaysVersion: Int
    let calendar: Calendar
    let findWorkDays: (Date) -> [WorkDay]
    let onSelect: (Date, WorkDay?) -> Void
    let onEdit: (WorkDay) -> Void
    let onDelete: (WorkDay) -> Void
    let onAdd: (Date) -> Void

    // `slots` dérive de `month` (cache), `calendar` est constant, les closures
    // lisent l'état à jour via les boxes @State : seuls ces champs comptent.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.month == rhs.month &&
        lhs.selectedDate == rhs.selectedDate &&
        lhs.today == rhs.today &&
        lhs.showWeekNumbers == rhs.showWeekNumbers &&
        lhs.eventDisplayMode == rhs.eventDisplayMode &&
        lhs.workDaysVersion == rhs.workDaysVersion
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: today, toGranularity: .month)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Le mois courant est teinté, façon Calendrier Apple.
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(isCurrentMonth ? Color.blue : Color.primary)
                .padding(.leading, DS.Spacing.xs)
                .padding(.top, DS.Spacing.sm)

            VStack(spacing: 0) {
                ForEach(Array(stride(from: 0, to: slots.count, by: 7)), id: \.self) { weekStart in
                    if weekStart > 0 {
                        Divider()
                    }

                    HStack(alignment: .top, spacing: 0) {
                        if showWeekNumbers {
                            Text(weekNumberText(for: slots[weekStart..<min(weekStart + 7, slots.count)]))
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundStyle(.tertiary)
                                .frame(width: 22, alignment: .leading)
                                .padding(.top, DS.Spacing.md)
                        }

                        ForEach(slots[weekStart..<min(weekStart + 7, slots.count)]) { slot in
                            if let date = slot.date {
                                dayCell(for: date)
                            } else {
                                // Cellule vide
                                Color.clear
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func dayCell(for date: Date) -> some View {
        let workDays = findWorkDays(date)
        let workDay = workDays.first
        let isSelected = selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
        let isToday = calendar.isDate(date, inSameDayAs: today)

        return Button {
            onSelect(date, workDay)
        } label: {
            ImprovedCalendarCell(
                date: date,
                workDays: workDays,
                isSelected: isSelected,
                isToday: isToday,
                isWeekend: calendar.isDateInWeekend(date),
                eventDisplayMode: eventDisplayMode
            )
        }
        .buttonStyle(.plain)
        // Appui long : actions rapides sans passer par la carte de détail
        .contextMenu {
            if let workDay {
                Button {
                    onEdit(workDay)
                } label: {
                    Label("action.edit".localized, systemImage: "pencil")
                }

                Button(role: .destructive) {
                    onDelete(workDay)
                } label: {
                    Label("action.delete".localized, systemImage: "trash")
                }
            } else {
                Button {
                    onAdd(date)
                } label: {
                    Label("action.add".localized, systemImage: "plus")
                }
            }
        }
        .accessibilityIdentifier("calendar-day-\(CalendarGridLayout.dateIdentity(for: date, calendar: calendar))")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: date, workDays: workDays, isToday: isToday))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            onSelect(date, workDay)
        }
    }

    /// « Juin », ou « Juin 2027 » si l'année diffère de l'année en cours.
    private var title: String {
        let name = month.formatted(.dateTime.month(.wide)).capitalized
        let year = calendar.component(.year, from: month)
        let currentYear = calendar.component(.year, from: today)
        return year == currentYear ? name : "\(name) \(year)"
    }

    private func weekNumberText(for slots: ArraySlice<CalendarMonthSlot>) -> String {
        guard let date = slots.compactMap(\.date).first else { return "" }
        return String(calendar.component(.weekOfYear, from: date))
    }

    private func accessibilityLabel(for date: Date, workDays: [WorkDay], isToday: Bool) -> String {
        var parts = [date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())]

        if isToday {
            parts.append("calendar.today".localized)
        }

        if !workDays.isEmpty {
            if workDays.count > 1 {
                parts.append("workDays.entries.count".localized(workDays.count))
            }
            let types = WorkDayType.allCases.filter { type in workDays.contains { $0.type == type } }
            parts.append(contentsOf: types.map(\.localizedName))
            let hours = workDays.reduce(0) { $0 + $1.totalHours }
            parts.append("calendar.preview.hours".localized(WorkTimeCalculations.formattedHoursRounded(hours)))
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Sous-vues améliorées

/// Cellule de calendrier améliorée avec design Liquid Glass
/// Étiquette capsule du type de journée, façon événement Calendrier Apple.
/// Contraste renforcé + fallback opaque si reduceTransparency.
struct DayTypeBadge: View {
    let type: WorkDayType

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Text(type.localizedName)
            .font(.caption2)
            .fontWeight(.semibold)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(reduceTransparency ? Color.white : type.color)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity)
            .background(
                type.color.opacity(reduceTransparency ? 1.0 : (colorScheme == .dark ? 0.30 : 0.20)),
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
            )
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

struct ImprovedCalendarCell: View {
    let date: Date
    let workDays: [WorkDay]
    let isSelected: Bool
    let isToday: Bool
    var isWeekend: Bool = false
    var eventDisplayMode: CalendarEventDisplayMode = .compact

    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let calendar = CalendarGridLayout.displayCalendar

    private var workDay: WorkDay? { workDays.first }
    private var entryCount: Int { workDays.count }
    private var totalHours: Double { workDays.reduce(0) { $0 + $1.totalHours } }

    private var typeRepresentatives: [WorkDay] {
        var seenTypes = Set<String>()
        return workDays.filter { seenTypes.insert($0.typeRawValue).inserted }
    }

    var body: some View {
        VStack(spacing: 3) {
            // Numéro du jour dans un cercle (visible uniquement si sélectionné/aujourd'hui)
            ZStack {
                if isSelected {
                    // Façon Calendrier Apple : aujourd'hui = cercle accent,
                    // autre jour = cercle plein contrasté (noir en clair, blanc en sombre).
                    Circle()
                        .fill(isToday ? Color.blue : Color.primary)
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
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .frame(width: 34, height: 34)

            // Calendrier propose une présentation compacte ou détaillée des événements.
            if let workDay {
                switch eventDisplayMode {
                case .compact:
                    let layout = dynamicTypeSize >= .xxLarge
                        ? AnyLayout(VStackLayout(spacing: 1))
                        : AnyLayout(HStackLayout(spacing: 3))
                    layout {
                        HStack(spacing: 3) {
                            ForEach(typeRepresentatives.prefix(2)) { entry in
                                Image(systemName: entry.type.icon)
                                    .foregroundStyle(entry.type.color)
                            }
                        }
                        if entryCount > min(typeRepresentatives.count, 2) {
                            Text("+\(entryCount - min(typeRepresentatives.count, 2))")
                                .foregroundStyle(DS.Colors.secondaryText)
                                .fixedSize()
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityHidden(true)
                case .stack:
                    HStack(spacing: 2) {
                        DayTypeBadge(type: workDay.type)
                        if entryCount > 1 {
                            Text("+\(entryCount - 1)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(DS.Colors.secondaryText)
                        }
                    }
                    .padding(.horizontal, 2)
                case .details:
                    VStack(spacing: 1) {
                        DayTypeBadge(type: workDay.type)
                        if totalHours > 0 {
                            Text(WorkTimeCalculations.formattedHoursTruncated(totalHours))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(DS.Colors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            } else {
                Color.clear
                    .frame(height: eventDisplayMode == .compact ? 14 : 17)
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .frame(minHeight: eventDisplayMode == .compact ? 56 : eventDisplayMode == .stack ? 63 : 72, alignment: .top)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // Couleur du texte basée sur l'état
    private var textColor: Color {
        if isSelected {
            // Sur cercle accent → blanc ; sur cercle Color.primary → couleur inversée
            return isToday ? .white : Color(.systemBackground)
        } else if isToday {
            return .blue
        }
        return isWeekend ? .secondary : .primary
    }
}

/// Ligne horaire inspirée de la présentation Jour de Calendrier Apple.
private struct WorkDayTimelineView: View {
    let date: Date
    let workDays: [WorkDay]
    let calendar: Calendar
    let onAdd: () -> Void
    let onEdit: (WorkDay) -> Void
    let onDelete: (WorkDay) -> Void

    private let hourHeight: CGFloat = 68
    private let hourLabelWidth: CGFloat = 54
    private let timelineTopInset: CGFloat = 8

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    daySummary

                    ZStack(alignment: .topLeading) {
                        timelineGrid

                        ForEach(timedWorkDays) { workDay in
                            timelineEvent(workDay)
                        }

                        if calendar.isDateInToday(date) {
                            currentTimeIndicator
                        }
                    }
                    .frame(height: hourHeight * 24)
                    .accessibilityIdentifier("calendar.timeline")
                }
            }
            .scrollIndicators(.visible)
            .task(id: CalendarGridLayout.dateIdentity(for: date, calendar: calendar)) {
                await Task.yield()
                proxy.scrollTo(initialScrollHour, anchor: .top)
            }
        }
    }

    @ViewBuilder
    private var daySummary: some View {
        if workDays.isEmpty {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "calendar.badge.plus")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("calendar.day.noEntry".localized)
                        .font(.subheadline.weight(.semibold))
                    Text("calendar.day.noEntry.detail".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button("action.add".localized, action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding()
            .background(.regularMaterial)
        } else {
            VStack(spacing: DS.Spacing.xs) {
                if workDays.count > 1 {
                    dailyAggregateSummary
                }

                ForEach(nonTimedWorkDays) { workDay in
                    nonTimedSummary(workDay)
                }
            }
        }
    }

    private var dailyAggregateSummary: some View {
        let totalHours = workDays.reduce(0.0) { $0 + $1.totalHours }
        let overtimeSeconds = workDays.reduce(0) { $0 + $1.overtimeSeconds }
        let formattedBalance = WorkTimeCalculations.formattedSecondsRounded(overtimeSeconds)

        return HStack(spacing: DS.Spacing.md) {
            Label("workDays.entries.count".localized(workDays.count), systemImage: "rectangle.stack.fill")
                .font(.subheadline.weight(.semibold))

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(WorkTimeCalculations.formattedHoursRounded(totalHours))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(overtimeSeconds > 0 ? "+\(formattedBalance)" : formattedBalance)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DS.Colors.balance(Double(overtimeSeconds)))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, DS.Spacing.sm)
        .background(.regularMaterial)
    }

    private func nonTimedSummary(_ workDay: WorkDay) -> some View {
        Button {
            onEdit(workDay)
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: workDay.type.icon)
                    .foregroundStyle(workDay.type.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(workDay.type.localizedName)
                        .font(.headline)
                    if let note = workDay.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(workDay.type.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete(workDay)
            } label: {
                Label("action.delete".localized, systemImage: "trash")
            }
        }
    }

    private var timedWorkDays: [WorkDay] {
        workDays
            .filter { $0.type.isWorkDay && $0.startTime != nil && $0.endTime != nil }
            .sorted { ($0.startTime ?? $0.date) < ($1.startTime ?? $1.date) }
    }

    private var nonTimedWorkDays: [WorkDay] {
        workDays.filter {
            !$0.type.isWorkDay || $0.startTime == nil || $0.endTime == nil
        }
    }

    private var timelineGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                ZStack(alignment: .topLeading) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(format: "%02d:00", hour))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: hourLabelWidth, alignment: .trailing)
                            .offset(y: -7)

                        Rectangle()
                            .fill(Color.secondary.opacity(0.22))
                            .frame(height: 0.5)
                    }
                    .offset(y: timelineTopInset)
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour)
            }
        }
        .padding(.trailing)
    }

    private func timelineEvent(_ workDay: WorkDay) -> some View {
        Button {
            onEdit(workDay)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(workDay.type.localizedName)
                    .font(.headline)
                    .lineLimit(1)
                Text(timeRange(for: workDay))
                    .font(.caption.monospacedDigit())
                HStack(spacing: 8) {
                    Text(workDay.formattedTotalHours)
                    if workDay.breakDuration > 0 {
                        Text("calendar.timeline.break".localized(formatDuration(workDay.breakDuration)))
                    }
                }
                .font(.caption2)
                .lineLimit(1)
            }
            .foregroundStyle(workDay.type.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                workDay.type.color.opacity(0.20),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(workDay.type.color)
                    .frame(width: 5)
                    .padding(.vertical, 7)
            }
        }
        .buttonStyle(.plain)
        .frame(height: eventHeight(for: workDay))
        .padding(.leading, hourLabelWidth + 14)
        .padding(.trailing, 10)
        .offset(y: timelineTopInset + eventOffset(for: workDay))
        .contextMenu {
            Button {
                onEdit(workDay)
            } label: {
                Label("action.edit".localized, systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete(workDay)
            } label: {
                Label("action.delete".localized, systemImage: "trash")
            }
        }
        .accessibilityIdentifier("calendar.timeline-event")
    }

    private var currentTimeIndicator: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
            Rectangle()
                .fill(Color.red)
                .frame(height: 1)
        }
        .padding(.leading, hourLabelWidth + 7)
        .padding(.trailing, 8)
        .offset(y: timelineTopInset + minutesSinceStartOfDay(Date()) / 60 * hourHeight)
        .accessibilityHidden(true)
    }

    private var initialScrollHour: Int {
        guard let start = timedWorkDays.compactMap(\.startTime).min() else { return 8 }
        return max(calendar.component(.hour, from: start) - 1, 0)
    }

    private func eventOffset(for workDay: WorkDay) -> CGFloat {
        guard let start = workDay.startTime else { return 0 }
        return minutesSinceStartOfDay(start) / 60 * hourHeight
    }

    private func eventHeight(for workDay: WorkDay) -> CGFloat {
        guard let start = workDay.startTime, let end = workDay.endTime else { return 54 }
        let duration = max(end.timeIntervalSince(start) / 3600, 0.75)
        return CGFloat(min(duration, 24)) * hourHeight
    }

    private func minutesSinceStartOfDay(_ value: Date) -> CGFloat {
        let components = calendar.dateComponents([.hour, .minute], from: value)
        return CGFloat((components.hour ?? 0) * 60 + (components.minute ?? 0))
    }

    private func timeRange(for workDay: WorkDay) -> String {
        guard let start = workDay.startTime, let end = workDay.endTime else { return "" }
        return "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return String(format: "%dh%02d", minutes / 60, minutes % 60)
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
