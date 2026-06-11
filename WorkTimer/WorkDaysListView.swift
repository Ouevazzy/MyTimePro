import SwiftUI
import SwiftData

private struct WorkDayListSection: Identifiable {
    let date: Date
    let days: [WorkDay]

    var id: Date { date }
}

struct WorkDayMonthSelection: Hashable {
    let startDate: Date
    let year: Int
    let month: Int

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)
        let normalizedDate = calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: components.year,
            month: components.month,
            day: 1
        )) ?? calendar.startOfDay(for: date)

        startDate = calendar.startOfDay(for: normalizedDate)
        year = components.year ?? calendar.component(.year, from: startDate)
        month = components.month ?? calendar.component(.month, from: startDate)
    }

    func addingMonths(_ value: Int, calendar: Calendar = .current) -> WorkDayMonthSelection? {
        guard let date = calendar.date(byAdding: .month, value: value, to: startDate) else {
            return nil
        }

        return WorkDayMonthSelection(date: date, calendar: calendar)
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.component(.year, from: date) == year &&
        calendar.component(.month, from: date) == month
    }
}

struct WorkDaysListView: View {
    // MARK: - Environment & Properties
    @Environment(\.modelContext) private var modelContext
    var startInSearch: Bool = false
    
    // MARK: - State
    @State private var showAddWorkDayView = false
    @State private var selectedWorkDay: WorkDay?
    @State private var visibleMonth = WorkDayMonthSelection(date: Date())
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showingFilters = false
    @State private var selectedType: WorkDayType? = nil
    @State private var animateList = false
    @State private var isEditMode = false
    @State private var selectedWorkDays: Set<UUID> = []
    @State private var selectedDates: Set<Date> = []
    @State private var showingDeleteConfirmation = false
    
    // MARK: - Nouvelles propriétés pour l'optimisation
    @State private var monthWorkDays: [WorkDay] = []
    @State private var filteredWorkDays: [WorkDay] = []
    @State private var groupedWorkDays: [Date: [WorkDay]] = [:]
    @State private var workDaySections: [WorkDayListSection] = []
    @State private var isFilteringData = false
    @State private var cachedMonthlyStats: (totalHours: Double, overtimeSeconds: Int, totalBonus: Double) = (0, 0, 0)
    @State private var loadTask: Task<Void, Never>?
    @State private var searchTask: Task<Void, Never>?

    // MARK: - Computed Properties
    private var currentMonth: Int {
        visibleMonth.month
    }

    private var selectedYear: Int {
        visibleMonth.year
    }

    private var isCurrentMonth: Bool {
        visibleMonth.contains(Date())
    }
    
    private var hasFilterActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedType != nil
    }
    
    private var noResults: Bool {
        workDaySections.isEmpty
    }

    private var defaultNewWorkDayDate: Date {
        visibleMonth.startDate
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            monthNavigationHeader
            
            if !isSearching {
                MonthlyStatsHeader(stats: cachedMonthlyStats)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if isFilteringData {
                ProgressView("loading".localized)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if noResults {
                emptyStateView
            } else {
                workDaysList
            }
        }
        .dsScreenBackground(.blue)
        .navigationTitle("workDay.title".localized)
        .searchable(
            text: $searchText,
            isPresented: $isSearching,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "search.placeholder".localized
        )
        .searchSuggestions {
            ForEach(WorkDayType.allCases, id: \.self) { type in
                Label(type.localizedName, systemImage: type.icon)
                    .searchCompletion(type.localizedName)
            }
        }
        .sensoryFeedback(.selection, trigger: selectedWorkDays.count)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !isEditMode {
                    Button(action: {
                        withAnimation(DS.Animation.interactive) {
                            isEditMode = true
                        }
                    }) {
                        Text("action.select".localized)
                    }
                    .disabled(filteredWorkDays.isEmpty)
                } else {
                    Button(action: {
                        withAnimation(DS.Animation.interactive) {
                            isEditMode = false
                            selectedWorkDays.removeAll()
                            selectedDates.removeAll()
                        }
                    }) {
                        Text("action.cancel".localized)
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                if isEditMode && !selectedWorkDays.isEmpty {
                    // Supprimer
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Label("action.delete".localized, systemImage: "trash")
                    }
                    .foregroundStyle(.red)
            } else {
                    HStack(spacing: 16) {
                        filterButton
                        addButton
                    }
                }
            }
        }
        .sheet(isPresented: $showAddWorkDayView, onDismiss: {
            filterWorkDaysAsync()
        }) {
            NavigationStack {
                AddEditWorkDayView(workDay: WorkDay(date: defaultNewWorkDayDate, type: .work))
            }
        }
        .sheet(item: $selectedWorkDay, onDismiss: {
            filterWorkDaysAsync()
        }) { workDay in
            NavigationStack {
                AddEditWorkDayView(workDay: workDay)
            }
        }
        .alert("delete.confirm.title".localized, isPresented: $showingDeleteConfirmation) {
            Button("action.cancel".localized, role: .cancel) { }
            Button("action.delete".localized, role: .destructive) {
                performBatchDelete()
            }
        } message: {
            let count = selectedWorkDays.count
            let plural = count > 1 ? "delete.confirm.days".localized : "delete.confirm.day".localized
            Text("delete.confirm.message".localized(count, plural))
        }
        .sheet(isPresented: $showingFilters) {
            NavigationStack {
                filterSheetContent
                    .navigationTitle("filter.title".localized)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            if selectedType != nil {
                                Button("filter.clear".localized) {
                                    withAnimation(DS.Animation.micro) {
                                        selectedType = nil
                                        showingFilters = false
                                        applySearchAndTypeFilterAsync()
                                    }
                                }
                                .foregroundStyle(.red)
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("action.done".localized) {
                                showingFilters = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .withErrorHandling()
        .onAppear {
            Analytics.shared.logScreenView("workDays")
            if startInSearch && !isSearching {
                isSearching = true
            }
            filterWorkDaysAsync()
        }
        .onChange(of: visibleMonth) { _, _ in
            filterWorkDaysAsync()
        }
        .onChange(of: searchText) { _, _ in
            applySearchAndTypeFilterAsync()
        }
        .onChange(of: selectedType) { _, _ in
            applySearchAndTypeFilterAsync()
        }
        .onDisappear {
            loadTask?.cancel()
            searchTask?.cancel()
        }
    }
    
    // MARK: - Components
    private var monthNavigationHeader: some View {
        HStack {
            Button { navigateToPreviousMonth() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(width: DS.Touch.minSize, height: DS.Touch.minSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
            .accessibilityLabel("accessibility.previousMonth".localized)

            Spacer()

            VStack(spacing: DS.Spacing.xs) {
                Text(monthYearString)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())

                if !isCurrentMonth {
                    Button { navigateToCurrentMonth() } label: {
                        Label("calendar.today".localized, systemImage: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .dsGlassSurface(cornerRadius: DS.Radius.medium, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .animation(DS.Animation.navigation, value: isCurrentMonth)

            Spacer()

            Button { navigateToNextMonth() } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .frame(width: DS.Touch.minSize, height: DS.Touch.minSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.glass)
            .accessibilityLabel("accessibility.nextMonth".localized)
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal)
        .background(.regularMaterial)
    }

    private var workDaysList: some View {
        List {
            ForEach(workDaySections) { section in
                let dateKey = section.date
                let days = section.days

                Section(header: CustomSectionHeader(
                    date: formatSectionDate(dateKey),
                    isToday: isToday(dateKey),
                    isEditMode: isEditMode,
                    isSelected: selectedDates.contains(dateKey),
                    onToggleSelection: {
                        toggleDateSelection(dateKey, days)
                    }
                )) {
                    ForEach(days) { workDay in
                        WorkDayRow(
                            workDay: workDay,
                            isSelected: selectedWorkDays.contains(workDay.id),
                            isEditMode: isEditMode
                        )
                        .equatable()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditMode {
                                toggleSelection(for: workDay)
                            } else {
                                selectedWorkDay = workDay
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation(DS.Animation.interactive) {
                                    deleteWorkDay(workDay)
                                }
                            } label: {
                                Label("action.delete".localized, systemImage: "trash")
                            }
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .dsGlassSurface(cornerRadius: DS.Radius.medium)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable {
            // Rafraîchir les données
            filterWorkDaysAsync()
        }
        .environment(\.editMode, isEditMode ? .constant(.active) : .constant(.inactive))
    }
    
    private var emptyStateView: some View {
        EmptyStateView(
            icon: hasFilterActive ? "text.magnifyingglass" : "calendar.badge.plus",
            title: hasFilterActive ? "empty.noResults.title".localized : "empty.noWorkDays.title".localized,
            subtitle: hasFilterActive
                ? "empty.noResults.message".localized
                : "empty.noWorkDays.message".localized,
            actionTitle: hasFilterActive ? "empty.noResults.action".localized : "empty.noWorkDays.action".localized,
            action: {
                if hasFilterActive {
                    withAnimation(DS.Animation.appear) {
                        searchText = ""
                        isSearching = false
                        selectedType = nil
                        showingFilters = false
                        applySearchAndTypeFilterAsync()
                    }
                } else {
                    showAddWorkDayView = true
                }
            },
            iconColors: hasFilterActive ? [.orange, .red] : [.blue, .purple]
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addButton: some View {
        Button(action: {
            showAddWorkDayView = true
        }) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
        }
    }
    
    /// Bouton qui ouvre/ferme le panneau de filtres
    private var filterButton: some View {
        Button(action: {
            withAnimation(DS.Animation.interactive) {
                showingFilters.toggle()
            }
        }) {
            Image(systemName: hasFilterActive
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .font(.title3)
                .foregroundStyle(hasFilterActive ? .blue : .secondary)
        }
    }
    
    private var filterSheetContent: some View {
        List {
            Section {
                TypeFilterButton(
                    type: nil,
                    selectedType: $selectedType,
                    icon: "list.bullet",
                    color: .secondary
                ) {
                    withAnimation(DS.Animation.micro) { showingFilters = false }
                }
                ForEach(WorkDayType.allCases, id: \.self) { type in
                    TypeFilterButton(
                        type: type,
                        selectedType: $selectedType,
                        icon: type.icon,
                        color: type.color
                    ) {
                        withAnimation(DS.Animation.micro) { showingFilters = false }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Helper Methods
    
    /// Filtre les workDays sur le mois/année sélectionnés.
    /// ✅ Perf Apple WWDC23: FetchDescriptor ciblé avec prédicat SQL au lieu de filter() en mémoire.
    /// propertiesToFetch: seuls les champs nécessaires à l'affichage sont chargés.
    private func filterWorkDaysAsync() {
        loadTask?.cancel()
        searchTask?.cancel()
        isFilteringData = true
        let requestedMonth = visibleMonth

        loadTask = Task { @MainActor in
            guard !Task.isCancelled else { isFilteringData = false; return }
            let calendar = Calendar.current
            guard let startOfMonth = calendar.date(from: DateComponents(year: requestedMonth.year, month: requestedMonth.month, day: 1)),
                  let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                isFilteringData = false
                return
            }

            do {
                // ✅ Prédicat SQL : filtré en base, pas en mémoire
                var descriptor = FetchDescriptor<WorkDay>(
                    predicate: #Predicate<WorkDay> { workDay in
                        workDay.date >= startOfMonth &&
                        workDay.date < endOfMonth &&
                        !workDay.isDeleted
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )

                // ✅ propertiesToFetch : charge uniquement les champs utilisés dans la liste
                // Les champs non listés sont chargés à la demande (faulting automatique)
                descriptor.propertiesToFetch = [
                    \.id, \.date, \.typeRawValue, \.totalHours,
                    \.overtimeSeconds, \.bonusAmount, \.note,
                    \.startTime, \.endTime, \.breakDuration,
                    \.isDeleted, \.modifiedAt
                ]

                let filtered = try modelContext.fetch(descriptor)
                guard !Task.isCancelled,
                      requestedMonth == visibleMonth
                else {
                    isFilteringData = false
                    return
                }

                monthWorkDays = filtered
                cachedMonthlyStats = monthlyStats(from: filtered)
                applyCurrentFilters(to: filtered)
                self.isFilteringData = false

                withAnimation(DS.Animation.appear) { self.animateList = true }

            } catch {
                AppLogger.error("WorkDays fetch failed", category: AppLogger.general, error: error)
                self.monthWorkDays = []
                self.filteredWorkDays = []
                self.groupedWorkDays = [:]
                self.workDaySections = []
                self.cachedMonthlyStats = (0, 0, 0)
                self.isFilteringData = false
            }
        }
    }
    
    /// Applique les filtres de recherche et de type
    private func applySearchAndTypeFilterAsync() {
        searchTask?.cancel()
        let searchSnapshot = searchText

        searchTask = Task { @MainActor in
            if !searchSnapshot.isEmpty {
                try? await Task.sleep(for: .milliseconds(180))
            }
            guard !Task.isCancelled else { return }
            applyCurrentFilters(to: monthWorkDays)
            
            // Animer l'apparition progressive des éléments
            withAnimation(DS.Animation.appear) {
                self.animateList = true
            }
        }
    }
    
    /// Filtre les WorkDays du mois déjà chargé, sans nouveau passage SwiftData.
    private func filterWorkDaysWithSearchAndType(_ workDays: [WorkDay]) -> [WorkDay] {
        let normalizedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        return workDays.filter { workDay in
            let matchesType = selectedType == nil || workDay.type == selectedType
            let matchesSearch = normalizedSearchText.isEmpty ||
                (workDay.note?.localizedStandardContains(normalizedSearchText) ?? false) ||
                workDay.type.localizedName.localizedStandardContains(normalizedSearchText)

            return matchesType && matchesSearch
        }
    }

    private func applyCurrentFilters(to workDays: [WorkDay]) {
        replaceDisplayedWorkDays(with: filterWorkDaysWithSearchAndType(workDays))
    }

    private func replaceDisplayedWorkDays(with workDays: [WorkDay]) {
        filteredWorkDays = workDays

        let grouped = Dictionary(grouping: workDays) { dayOnly(from: $0.date) }
        groupedWorkDays = grouped
        workDaySections = grouped.keys.sorted(by: >).map { date in
            WorkDayListSection(
                date: date,
                days: grouped[date, default: []].sorted { $0.date > $1.date }
            )
        }
    }

    private func monthlyStats(from workDays: [WorkDay]) -> (totalHours: Double, overtimeSeconds: Int, totalBonus: Double) {
        var totalHours = 0.0
        var overtimeSeconds = 0
        var totalBonus = 0.0

        for workDay in workDays {
            totalHours += workDay.totalHours
            overtimeSeconds += workDay.overtimeSeconds
            totalBonus += workDay.bonusAmount
        }

        return (totalHours, overtimeSeconds, totalBonus)
    }
    
    /// Gère la sélection/désélection d'un workDay
    private func toggleSelection(for workDay: WorkDay) {
        if selectedWorkDays.contains(workDay.id) {
            selectedWorkDays.remove(workDay.id)
            // Vérifier si nous devons aussi retirer la date du Set selectedDates
            let dayDate = dayOnly(from: workDay.date)
            if let daysForDate = groupedWorkDays[dayDate] {
                let allDayIdsSelected = daysForDate.allSatisfy {
                    selectedWorkDays.contains($0.id)
                }
                if !allDayIdsSelected {
                    selectedDates.remove(dayDate)
                }
            }
        } else {
            selectedWorkDays.insert(workDay.id)
            // Vérifier si nous devons ajouter la date au Set selectedDates
            let dayDate = dayOnly(from: workDay.date)
            if let daysForDate = groupedWorkDays[dayDate] {
                let allDayIdsSelected = daysForDate.allSatisfy {
                    selectedWorkDays.contains($0.id) || $0.id == workDay.id
                }
                if allDayIdsSelected {
                    selectedDates.insert(dayDate)
                }
            }
        }
    }
    
    /// Gère la sélection/désélection d'une journée entière
    private func toggleDateSelection(_ date: Date, _ workDays: [WorkDay]) {
        // Vérifier si la date est déjà sélectionnée
        if selectedDates.contains(date) {
            // Désélectionner tous les WorkDay pour cette date
            selectedDates.remove(date)
            for workDay in workDays {
                selectedWorkDays.remove(workDay.id)
            }
        } else {
            // Sélectionner tous les WorkDay pour cette date
            selectedDates.insert(date)
            for workDay in workDays {
                selectedWorkDays.insert(workDay.id)
            }
        }
    }

    /// Exécute la suppression par lot des journées sélectionnées
    private func performBatchDelete() {
        let workDaysToDelete = filteredWorkDays.filter { selectedWorkDays.contains($0.id) }

        for workDay in workDaysToDelete {
            StatsCache.shared.onWorkDayDeleted(workDay)
            modelContext.delete(workDay)
        }
        
        // Sauvegarde du contexte
        do {
            try modelContext.save()
            SiriSummaryCacheService().refresh(using: modelContext)
            
            // Réinitialiser la sélection et quitter le mode édition
            withAnimation(DS.Animation.interactive) {
                selectedWorkDays.removeAll()
                selectedDates.removeAll()
                isEditMode = false
            }
            
            // Réactualiser la liste après suppression
            filterWorkDaysAsync()
            
        } catch {
            ErrorManager.shared.handle(error, context: "BatchDeleteWorkDays")
        }
    }
    
    /// Supprime un WorkDay
    private func deleteWorkDay(_ workDay: WorkDay) {
        let workDayID = workDay.id
        StatsCache.shared.onWorkDayDeleted(workDay)
        modelContext.delete(workDay)
        
        // Sauvegarde du contexte
        do {
            try modelContext.save()
            SiriSummaryCacheService().refresh(using: modelContext)
            
            // Actualiser la liste filtrée et le groupement
            monthWorkDays.removeAll { $0.id == workDayID }
            cachedMonthlyStats = monthlyStats(from: monthWorkDays)
            applyCurrentFilters(to: monthWorkDays)
            
        } catch {
            ErrorManager.shared.handle(error, context: "DeleteWorkDay")
        }
    }
    
    /// Naviguer vers le mois précédent
    private func navigateToPreviousMonth() {
        if let previousMonth = visibleMonth.addingMonths(-1) {
            clearSelection()
            visibleMonth = previousMonth
            animateList = false
        }
    }
    
    /// Naviguer vers le mois suivant
    private func navigateToNextMonth() {
        if let nextMonth = visibleMonth.addingMonths(1) {
            clearSelection()
            visibleMonth = nextMonth
            animateList = false
        }
    }
    
    /// Revenir au mois courant
    private func navigateToCurrentMonth() {
        clearSelection()
        visibleMonth = WorkDayMonthSelection(date: Date())
        animateList = false
    }

    private func clearSelection() {
        selectedWorkDays.removeAll()
        selectedDates.removeAll()
        isEditMode = false
    }
    
    /// Normalise la date à 00:00 (début de journée)
    private func dayOnly(from date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
    
    /// Vérifie si une date correspond à "aujourd'hui"
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    /// Formatage de la date pour l'entête de section
    private func formatSectionDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
    
    /// Affichage du mois et de l'année sélectionnés
    private var monthYearString: String {
        visibleMonth.startDate.formatted(.dateTime.month(.wide).year())
    }
}

// MARK: - Custom Views

struct CustomSectionHeader: View {
    let date: String
    let isToday: Bool
    var isEditMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelection: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            if isEditMode {
                Button(action: {
                    onToggleSelection?()
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .blue : .gray)
                        .font(.title3)
                }
                .padding(.trailing, 8)
                .transition(.scale.combined(with: .opacity))
            }
            
            Text(date)
                .font(.headline)
            
            if isToday {
                Text("calendar.today".localized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.2))
                    .foregroundStyle(.blue)
                    .cornerRadius(4)
            }
            
            Spacer()
        }
    }
}

struct WorkDayRow: View, Equatable {
    let workDay: WorkDay
    var isSelected: Bool = false
    var isEditMode: Bool = false

    // Comparaison basée sur les valeurs affichées — SwiftUI skip le re-render si rien n'a changé
    static func == (lhs: WorkDayRow, rhs: WorkDayRow) -> Bool {
        lhs.workDay.id == rhs.workDay.id &&
        lhs.workDay.modifiedAt == rhs.workDay.modifiedAt &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isEditMode == rhs.isEditMode
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            if isEditMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.blue : Color.secondary)
                    .font(.title3)
                    .animation(DS.Animation.micro, value: isSelected)
            }

            // Badge icône type (style Apple Settings)
            Image(systemName: workDay.type.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(workDay.type.color, in: RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: DS.Spacing.sm) {
                    if workDay.type == .work {
                        Text(workDay.formattedTotalHours)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.medium)
                            .monospacedDigit()
                    } else {
                        Text(workDay.type.localizedName)
                            .font(.body)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    if workDay.type == .work && workDay.overtimeSeconds != 0 {
                        Text(workDay.formattedOvertimeHours)
                            .foregroundStyle(workDay.overtimeSeconds > 0 ? Color.green : Color.red)
                            .font(.system(.callout, design: .rounded))
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }

                    if workDay.bonusAmount > 0 {
                        Text("+" + String(format: "%.0f", workDay.bonusAmount))
                            .foregroundStyle(Color.orange)
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                }

                if let note = workDay.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, DS.Spacing.xs)
        .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)
        .animation(DS.Animation.micro, value: isSelected)
    }
}

struct MonthlyStatsHeader: View {
    let stats: (totalHours: Double, overtimeSeconds: Int, totalBonus: Double)

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Label {
                Text(WorkTimeCalculations.formattedHoursTruncated(stats.totalHours))
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            } icon: {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
            }

            Divider()
                .frame(height: 16)

            Label {
                Text(WorkTimeCalculations.formattedSecondsTruncated(stats.overtimeSeconds))
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(stats.overtimeSeconds >= 0 ? Color.green : Color.red)
                    .contentTransition(.numericText(countsDown: stats.overtimeSeconds < 0))
            } icon: {
                Image(systemName: stats.overtimeSeconds >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(stats.overtimeSeconds >= 0 ? Color.green : Color.red)
            }

            if stats.totalBonus > 0 {
                Divider()
                    .frame(height: 16)
                Label {
                    Text(String(format: "%.0f", stats.totalBonus))
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                        .contentTransition(.numericText())
                } icon: {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, DS.Spacing.sm)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 6) {
            // Icône style Apple Settings
            Image(systemName: icon)
                .font(.system(size: DS.Font.iconSmall, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: DS.IconSize.inline, height: DS.IconSize.inline)
                .background(color, in: RoundedRectangle(cornerRadius: DS.IconRadius.inline))

            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

struct TypeFilterButton: View {
    let type: WorkDayType?
    @Binding var selectedType: WorkDayType?
    let icon: String
    let color: Color
    let onSelect: () -> Void
    
    private var isSelected: Bool {
        if type == nil {
            return selectedType == nil
        } else {
            return type == selectedType
        }
    }
    
    var body: some View {
        Button(action: {
            withAnimation(DS.Animation.micro) {
                selectedType = type
                onSelect()
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
                
                Text(type?.localizedName ?? "filter.all".localized)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        WorkDaysListView()
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}
