import SwiftUI
import SwiftData

enum CalendarViewMode {
    case month
    case week
}

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    // État principal
    @State private var selectedDate = Date()
    @State private var displayDate = Date() // Date affichée (peut être différente de selectedDate)
    @State private var calendarViewMode: CalendarViewMode = .month
    @State private var isLoading = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    // Gestion des feuilles modales
    @State private var showingAddWorkDay = false
    @State private var showingEditSheet = false
    @State private var selectedWorkDay: WorkDay?
    @State private var showingDatePicker = false
    
    // Animation du mois
    @State private var slideDirection: SlideDirection = .none
    @State private var animateCalendar = false
    
    // Nouvelles optimisations
    @State private var displayedWorkDays: [WorkDay] = []
    @State private var workDaysByDate: [Date: WorkDay] = [:]  // Lookup O(1) au lieu de O(n)
    @State private var isFiltering = false
    @State private var cachedMonthDates: [Date?] = []
    @State private var cachedWeekDates: [Date] = []
    
    // Valeurs calculées
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    // Constantes d'animation
    private enum SlideDirection {
        case none, left, right
    }
    
    // Animation de transition entre les mois
    @Namespace private var monthTransition
    
    // Jours de la semaine commençant par lundi
    private let weekDaySymbols: [String] = {
        var symbols = Calendar.current.shortWeekdaySymbols
        let sunday = symbols.remove(at: 0)
        symbols.append(sunday)
        return symbols.map { $0.lowercased() }
    }()
    
    // MARK: - Computed Properties
    private var isSelectedDateToday: Bool {
        calendar.isDateInToday(selectedDate)
    }
    
    private var isDisplayedMonthCurrent: Bool {
        calendar.isDate(displayDate, equalTo: Date(), toGranularity: .month)
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
                // En-tête du calendrier
                calendarHeader
                
                // Mode de vue (mois/semaine)
                HStack {
                    Picker("Mode", selection: $calendarViewMode) {
                        Text("calendar.mode.month".localized).tag(CalendarViewMode.month)
                        Text("calendar.mode.week".localized).tag(CalendarViewMode.week)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: calendarViewMode) { _, newValue in
                        withAnimation(DS.Animation.navigation) {
                            // Réinitialiser l'animation lors du changement de mode
                            slideDirection = .none
                            animateCalendar = false
                        }
                        
                        // Recalculer les dates lorsque le mode change
                        Task {
                            try? await updateDisplayedWorkDays()
                        }
                    }
                    
                    // Bouton aujourd'hui
                    if !isSelectedDateToday {
                        Button(action: goToToday) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.caption)
                                Text("calendar.today".localized)
                                    .font(.caption)
                            }
                            .foregroundColor(.blue)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color(.systemBackground))
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 1)
                        }
                        .accessibilityLabel("accessibility.today".localized)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 4)
                
                // Ligne des jours de la semaine
                weekdayHeader
                
                // Affichage du calendrier selon le mode
                ZStack {
                    if isFiltering {
                        ProgressView("loading".localized)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if calendarViewMode == .month {
                        // Vue mensuelle avec animation
                        monthCalendarView
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: slideDirection == .right ? .leading : .trailing),
                                    removal: .move(edge: slideDirection == .right ? .trailing : .leading)
                                )
                            )
                    } else {
                        // Vue semaine
                        weekCalendarView
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: slideDirection == .right ? .leading : .trailing),
                                    removal: .move(edge: slideDirection == .right ? .trailing : .leading)
                                )
                            )
                    }
                }
                .animation(DS.Animation.navigation, value: displayDate)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { gesture in
                            withAnimation(DS.Animation.interactive) {
                            isDragging = true
                            dragOffset = gesture.translation.width
                            }
                        }
                        .onEnded { gesture in
                            isDragging = false
                            let threshold: CGFloat = 50
                            let velocity = gesture.predictedEndTranslation.width
                            
                            withAnimation(DS.Animation.navigation) {
                                if gesture.translation.width > threshold || velocity > 500 {
                                    // Glissement vers la droite -> mois/semaine précédent
                                    slideDirection = .right
                                    Haptic.impact(.light)
                                    if calendarViewMode == .month {
                                        shiftMonth(by: -1)
                                    } else {
                                        shiftWeek(by: -1)
                                    }
                                } else if gesture.translation.width < -threshold || velocity < -500 {
                                    // Glissement vers la gauche -> mois/semaine suivant
                                    slideDirection = .left
                                    Haptic.impact(.light)
                                    if calendarViewMode == .month {
                                        shiftMonth(by: 1)
                                    } else {
                                        shiftWeek(by: 1)
                                    }
                                }
                                dragOffset = 0
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
            .navigationTitle("calendar.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Analytics.shared.logScreenView("calendar")
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingDatePicker = true
                    }) {
                        Image(systemName: "calendar")
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddWorkDay = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddWorkDay, onDismiss: {
                Task { try? await updateDisplayedWorkDays() }
            }) {
                NavigationStack {
                    AddEditWorkDayView(workDay: WorkDay(date: calendar.startOfDay(for: selectedDate)))
                }
            }
            .sheet(isPresented: $showingEditSheet, onDismiss: {
                Task { try? await updateDisplayedWorkDays() }
            }) {
                if let workDay = selectedWorkDay {
                    NavigationStack {
                        AddEditWorkDayView(workDay: workDay)
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(
                    selectedDate: $selectedDate,
                    displayDate: $displayDate,
                    isPresented: $showingDatePicker
                )
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                // Assurez-vous que la date affichée correspond au mois de la date sélectionnée
                if !calendar.isDate(oldValue, equalTo: newValue, toGranularity: .month) {
                    withAnimation(DS.Animation.navigation) {
                        displayDate = newValue
                        slideDirection = .none
                    }
                }
                
                // Chercher un WorkDay pour la date sélectionnée
                selectedWorkDay = findWorkDay(for: newValue)
            }
            .onChange(of: displayDate) { _, _ in
                // Recalculer les dates et workdays affichés à chaque changement de mois/semaine
                Task {
                    try? await updateDisplayedWorkDays()
                }
            }
            .task {
                // Charger les données initiales
                do {
                    try await updateDisplayedWorkDays()
                } catch {
                    ErrorManager.shared.handle(error, context: "CalendarInitialLoad")
                }
            }
            .withErrorHandling()
    }

    // MARK: - Composants d'interface
    
    // En-tête avec navigation du calendrier
    private var calendarHeader: some View {
        HStack {
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
                    .foregroundColor(.blue)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)

            Spacer()

            // Titre du mois ou de la semaine avec effet de transition
            VStack(spacing: 4) {
                if calendarViewMode == .month {
                    Text(monthAndYear)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .matchedGeometryEffect(id: "monthTitle", in: monthTransition)
                } else {
                    Text(weekRange)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .matchedGeometryEffect(id: "weekTitle", in: monthTransition)
                }

                // Petit indicateur d'année si en mode semaine
                if calendarViewMode == .week {
                    Text(displayDate.formatted(.dateTime.year()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 50)

            Spacer()

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
                    .foregroundColor(.blue)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .background(Color(.systemGroupedBackground))
    }

    // En-tête des jours de la semaine
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekDaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    // Vue du calendrier mensuel - version optimisée
    private var monthCalendarView: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(cachedMonthDates.enumerated()), id: \.offset) { index, date in
                if let date = date {
                    let workDay = findWorkDay(for: date)
                    // Cellule avec jour
                    ImprovedCalendarCell(
                        date: date,
                        workDay: workDay,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date)
                    )
                    .onTapGesture {
                        withAnimation(DS.Animation.micro) {
                            selectedDate = date
                            selectedWorkDay = workDay
                        }
                    }
                    .id("cell-\(calendar.component(.day, from: date))")
                } else {
                    // Cellule vide
                    Color.clear
                        .aspectRatio(1, contentMode: .fill)
                }
            }
        }
        .padding(.horizontal)
        .id("month-\(calendar.component(.month, from: displayDate))-\(calendar.component(.year, from: displayDate))")
    }
    
    // Vue du calendrier hebdomadaire - version optimisée
    private var weekCalendarView: some View {
        VStack(spacing: 10) {
            // Jours de la semaine avec leur date
            HStack(spacing: 0) {
                ForEach(cachedWeekDates.indices, id: \.self) { index in
                    let date = cachedWeekDates[index]
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
                                .foregroundColor(
                                    calendar.isDate(date, inSameDayAs: selectedDate) ? .white :
                                        calendar.isDateInToday(date) ? .blue : .primary
                                )
                        }
                        
                        // Indicateur de type de journée
                        if let workDay = workDay {
                            Image(systemName: workDay.type.icon)
                                .font(.caption)
                                .foregroundColor(workDay.type.color)
                        } else {
                            Spacer()
                                .frame(height: 16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(DS.Animation.micro) {
                            selectedDate = date
                            selectedWorkDay = findWorkDay(for: date)
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
                weekDates: cachedWeekDates,
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
                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.small))
                }
                .buttonStyle(.pressable)

                Button {
                    withAnimation(DS.Animation.interactive) { deleteWorkDay(workDay) }
                } label: {
                    Label("action.delete".localized, systemImage: "trash")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                        .padding(.vertical, DS.Spacing.sm)
                        .padding(.horizontal, DS.Spacing.md)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.small))
                }
                .buttonStyle(.pressable)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, DS.Spacing.sm)
        }
        .padding(.vertical, DS.Spacing.sm)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        .padding(.horizontal)
        .padding(.bottom, DS.Spacing.sm)
    }
    
    // MARK: - Méthodes d'optimisation
    
    // ✅ FetchDescriptor ciblé sur la période visible.
    @MainActor
    private func updateDisplayedWorkDays() async throws {
        isFiltering = true

        let currentMode = calendarViewMode
        let currentDisplayDate = displayDate

        // Calcul des dates de la grille (pur calcul, pas de données SwiftData)
        let datesTask = Task.detached(priority: .userInitiated) { [calendar] in
            if currentMode == .month {
                return await (Self.computeMonthDates(for: currentDisplayDate, calendar: calendar), [Date]())
            } else {
                return await ([], Self.computeWeekDates(for: currentDisplayDate, calendar: calendar))
            }
        }
        let (monthDates, weekDates) = await datesTask.value

        // ✅ Fetch ciblé avec prédicat SQL — ne charge QUE les jours de la période visible
        var relevantWorkDays: [WorkDay] = []
        do {
            if currentMode == .month,
               let interval = calendar.dateInterval(of: .month, for: currentDisplayDate) {
                let start = interval.start
                let end   = interval.end
                var descriptor = FetchDescriptor<WorkDay>(
                    predicate: #Predicate<WorkDay> { $0.date >= start && $0.date < end },
                    sortBy: [SortDescriptor(\.date)]
                )
                descriptor.propertiesToFetch = [\.date, \.typeRawValue, \.totalHours, \.overtimeSeconds, \.startTime, \.endTime]
                relevantWorkDays = try modelContext.fetch(descriptor)

            } else if currentMode == .week,
                      let firstDay = weekDates.first, let lastDay = weekDates.last {
                var descriptor = FetchDescriptor<WorkDay>(
                    predicate: #Predicate<WorkDay> { $0.date >= firstDay && $0.date <= lastDay },
                    sortBy: [SortDescriptor(\.date)]
                )
                descriptor.propertiesToFetch = [\.date, \.typeRawValue, \.totalHours, \.overtimeSeconds, \.startTime, \.endTime]
                relevantWorkDays = try modelContext.fetch(descriptor)
            }
        } catch {
            AppLogger.error("Calendar fetch failed", category: AppLogger.general, error: error)
        }

        self.cachedMonthDates = monthDates
        self.cachedWeekDates = weekDates
        self.displayedWorkDays = relevantWorkDays

        // Pré-construire le dictionnaire pour lookup O(1) au lieu de O(n) par cellule
        var lookup: [Date: WorkDay] = [:]
        for wd in relevantWorkDays {
            let key = calendar.startOfDay(for: wd.date)
            lookup[key] = wd
        }
        self.workDaysByDate = lookup

        self.isFiltering = false
        self.selectedWorkDay = findWorkDay(for: selectedDate)
    }
    
    /// Calcule la liste des dates à afficher pour le mois donné
    static private func computeMonthDates(for date: Date, calendar: Calendar) -> [Date?] {
        // Intervalle du mois
        guard let interval = calendar.dateInterval(of: .month, for: date) else {
            return []
        }
        
        let firstDayOfMonth = interval.start
        guard let numberOfDaysInMonth = calendar.range(of: .day, in: .month, for: firstDayOfMonth)?.count else {
            return []
        }
        
        // Calcul de l'index du premier jour (pour aligner sur lundi)
        let startDayIndex = (calendar.component(.weekday, from: firstDayOfMonth) - calendar.firstWeekday + 7) % 7
        
        // Génération du tableau
        var dates: [Date?] = []
        
        // Cases vides avant le premier jour
        for _ in 0..<startDayIndex {
            dates.append(nil)
        }
        
        // Toutes les dates du mois
        for dayOffset in 0..<numberOfDaysInMonth {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstDayOfMonth) {
                dates.append(date)
            }
        }
        
        // Compléter pour faire un multiple de 7
        while dates.count % 7 != 0 {
            dates.append(nil)
        }
        
        return dates
    }
    
    /// Calcule les dates de la semaine pour la date donnée
    static private func computeWeekDates(for date: Date, calendar: Calendar) -> [Date] {
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) else {
            return []
        }
        
        return (0...6).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: weekStart)
        }
    }
    
    /// Calcule les dates de la semaine pour la date donnée (méthode d'instance)
    private func computeWeekDates(for date: Date) -> [Date] {
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) else {
            return []
        }
        
        return (0...6).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: weekStart)
        }
    }
    
    /// Génère un identifiant unique pour une semaine
    private func weekIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)"
    }
    
    /// Navigation vers le mois précédent ou suivant
    private func shiftMonth(by offset: Int) {
        if let newDate = calendar.date(byAdding: .month, value: offset, to: displayDate) {
            displayDate = newDate
            // Si la date sélectionnée n'est pas dans le nouveau mois, la réinitialiser
            if !calendar.isDate(selectedDate, equalTo: newDate, toGranularity: .month) {
                // Sélectionner le même jour dans le nouveau mois, ou le dernier jour du mois
                let day = min(
                    calendar.component(.day, from: selectedDate),
                    calendar.range(of: .day, in: .month, for: newDate)?.count ?? 28
                )
                
                if let newSelectedDate = calendar.date(
                    bySetting: .day,
                    value: day,
                    of: newDate
                ) {
                    selectedDate = newSelectedDate
                }
            }
        }
    }
    
    /// Navigation vers la semaine précédente ou suivante
    private func shiftWeek(by offset: Int) {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: offset, to: displayDate) {
            displayDate = newDate
            
            // Si la date sélectionnée n'est pas dans la nouvelle semaine, la réinitialiser
            let weekDates = computeWeekDates(for: newDate)
            guard let firstDay = weekDates.first, let lastDay = weekDates.last else { return }
            
            if selectedDate < firstDay || selectedDate > lastDay {
                // Sélectionner le même jour de la semaine dans la nouvelle semaine
                let weekday = calendar.component(.weekday, from: selectedDate)
                if let newSelectedDate = calendar.date(
                    bySetting: .weekday,
                    value: weekday,
                    of: newDate
                ) {
                    selectedDate = newSelectedDate
                }
            }
        }
    }
    
    /// Met la date sélectionnée à aujourd'hui
    private func goToToday() {
        withAnimation(DS.Animation.appear) {
            let today = Date()
            selectedDate = today
            displayDate = today
            slideDirection = .none
        }
        
    }
    
    /// Supprime un WorkDay
    private func deleteWorkDay(_ workDay: WorkDay) {
        StatsCache.shared.onWorkDayDeleted(workDay)
        modelContext.delete(workDay)

        do {
            try modelContext.save()
            if selectedWorkDay?.id == workDay.id { selectedWorkDay = nil }
            displayedWorkDays.removeAll { $0.id == workDay.id }
        } catch {
            ErrorManager.shared.handle(error, context: "CalendarDeleteWorkDay")
        }
    }
    
    /// Trouve le WorkDay correspondant à une date via le dictionnaire pré-calculé (O(1))
    private func findWorkDay(for date: Date) -> WorkDay? {
        workDaysByDate[calendar.startOfDay(for: date)]
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
        f.locale = Locale(identifier: "fr_FR")
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f
    }()

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .full
        return f
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMM"
        return f
    }()

    private static let dayOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d"
        return f
    }()

    // Formats et textes
    private var monthAndYear: String {
        Self.monthYearFormatter.string(from: displayDate).lowercased()
    }

    private var weekRange: String {
        guard let firstDay = cachedWeekDates.first, let lastDay = cachedWeekDates.last else {
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

    private var hasEvents: Bool {
        !workDaysByDate.isEmpty
    }
    
    var body: some View {
        if hasEvents {
            ForEach(weekDates, id: \.self) { date in
                if let workDay = workDaysByDate[Calendar.current.startOfDay(for: date)] {
                    WeekDayEventRow(
                        workDay: workDay,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(DS.Animation.micro) {
                            selectedDate = date
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
                    .foregroundColor(.blue.opacity(0.7))
                
                Text("calendar.noEvents".localized)
                    .font(.headline)
                    .foregroundColor(.secondary)
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
                        .foregroundColor(workDay.type.color)
                    Text(workDay.type.localizedName)
                        .font(.headline)
                }
                
                if workDay.type == .work {
                    Text(workDay.formattedTotalHours)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Note si présente
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
                            .foregroundColor(
                                workDay.overtimeSeconds > 0 ? .green : .red
                            )
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

// MARK: - Sous-vues améliorées

/// Cellule de calendrier améliorée avec design Liquid Glass
struct ImprovedCalendarCell: View {
    let date: Date
    let workDay: WorkDay?
    let isSelected: Bool
    let isToday: Bool
    
    @Environment(\.colorScheme) var colorScheme
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            // Fond avec effet Liquid Glass
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .overlay {
                    if isToday && !isSelected {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.blue, lineWidth: 2)
                    }
                }
                .shadow(
                    color: isSelected ? Color.blue.opacity(0.2) : .clear,
                    radius: isSelected ? 4 : 0,
                    x: 0,
                    y: isSelected ? 2 : 0
                )
            
            VStack(spacing: 2) {
                // Indicateur "aujourd'hui"
                if isToday && !isSelected {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 6, height: 6)
                        .padding(.top, 2)
                }
                
                // Numéro du jour
                Text(String(calendar.component(.day, from: date)))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(isToday || isSelected ? .bold : .medium)
                    .foregroundStyle(textColor)
                
                // Indicateurs d'événements
                if let workDay = workDay {
                    // Icône de type avec effet de transition
                    Image(systemName: workDay.type.icon)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : workDay.type.color)
                        .font(.caption2)
                        .transition(.scale.combined(with: .opacity))
                    
                    // Badge pour les bonus
                    if workDay.bonusAmount > 0 {
                        Text("+" + String(format: "%.0f", workDay.bonusAmount))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.orange, .orange.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .aspectRatio(1, contentMode: .fill)
        .contentShape(Rectangle())
    }
    
    // Couleur de fond basée sur l'état et le type
    private var backgroundColor: Color {
        if isSelected {
            return .clear // Le gradient est appliqué via overlay
        } else if let workDay = workDay {
            // Couleur basée sur le type avec opacité adaptée au mode sombre/clair
            let opacity = colorScheme == .dark ? 0.15 : 0.12
            switch workDay.type {
            case .work:
                return Color.blue.opacity(opacity)
            case .vacation, .halfDayVacation:
                return Color.orange.opacity(opacity)
            case .sickLeave:
                return Color.red.opacity(opacity)
            case .compensatory:
                return Color.green.opacity(opacity)
            case .training:
                return Color.purple.opacity(opacity)
            case .holiday:
                return Color.yellow.opacity(opacity)
            }
        } else if isToday {
            return Color.blue.opacity(colorScheme == .dark ? 0.08 : 0.05)
        }
        return colorScheme == .dark ? Color(.systemGray6).opacity(0.5) : Color(.systemBackground)
    }
    
    // Couleur du texte basée sur l'état
    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .blue
        }
        return .primary
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
                        .foregroundColor(workDay.type.color)
                    
                    Text(workDay.type.rawValue)
                        .font(.headline)
                    
                    Spacer()
                    
                    if workDay.type == .work {
                        Text(workDay.formattedTotalHours)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let note = workDay.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                            .foregroundColor(workDay.overtimeSeconds > 0 ? .green : .red)
                        }
                        
                        if workDay.bonusAmount > 0 {
                            Spacer()
                            
                            Label(
                                String(format: "+%.0f", workDay.bonusAmount),
                                systemImage: "dollarsign.circle"
                            )
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected
                    ? workDay.type.color.opacity(0.1)
                    : Color(.systemBackground)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected ? workDay.type.color : Color.clear,
                            lineWidth: 1
                        )
                )
        )
        .animation(DS.Animation.micro, value: isSelected)
    }
}

/// Feuille modale de sélection de date
struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Binding var displayDate: Date
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "calendar.selectDate".localized,
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Button(action: {
                    displayDate = selectedDate
                    isPresented = false
                }) {
                    Text("action.confirm".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("calendar.selectDate".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.close".localized) {
                        isPresented = false
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
