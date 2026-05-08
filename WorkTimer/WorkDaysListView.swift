import SwiftUI
import SwiftData

struct WorkDaysListView: View {
    // MARK: - Environment & Properties
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    var startInSearch: Bool = false
    
    // MARK: - State
    @State private var showAddWorkDayView = false
    @State private var selectedWorkDay: WorkDay?
    @State private var selectedMonth = Date()
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showingFilters = false
    @State private var selectedType: WorkDayType? = nil
    @State private var animateList = false
    @State private var isEditMode = false
    @State private var selectedWorkDays: Set<UUID> = []
    @State private var selectedDates: Set<Date> = []
    @State private var showingDeleteConfirmation = false
    @FocusState private var isSearchFieldFocused: Bool
    
    // MARK: - Nouvelles propriétés pour l'optimisation
    @State private var filteredWorkDays: [WorkDay] = []
    @State private var groupedWorkDays: [Date: [WorkDay]] = [:]
    @State private var isFilteringData = false
    @State private var cachedMonthlyStats: (totalHours: Double, overtimeSeconds: Int, totalBonus: Double) = (0, 0, 0)
    @State private var filterTask: Task<Void, Never>?

    // MARK: - Computed Properties
    private var currentMonth: Int {
        Calendar.current.component(.month, from: selectedMonth)
    }

    private var isCurrentMonth: Bool {
        let calendar = Calendar.current
        let currentDate = Date()
        return calendar.component(.month, from: currentDate) == currentMonth &&
               calendar.component(.year, from: currentDate) == selectedYear
    }
    
    private var hasFilterActive: Bool {
        !searchText.isEmpty || selectedType != nil
    }
    
    private var noResults: Bool {
        groupedWorkDays.isEmpty
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            monthNavigationHeader
            
            if !isSearching {
                MonthlyStatsHeader(stats: cachedMonthlyStats)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            searchAndFilterBar
                .padding(.vertical, 8)
                .background(colorScheme == .dark ? Color(.systemBackground) : Color(.systemGroupedBackground))
            
            if isFilteringData {
                ProgressView("loading".localized)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if noResults {
                emptyStateView
            } else {
                workDaysList
            }
        }
        .navigationTitle("workDay.title".localized)
        .onAppear {
            Analytics.shared.logScreenView("workDays")
            if startInSearch && !isSearching {
                isSearching = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !isEditMode {
                    Button(action: {
                        withAnimation(DS.Animation.interactive) {
                            isEditMode = true
                        }
                    }) {
                        Text("action.select".localized)
                    }
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
                    .foregroundColor(.red)
            } else {
                    HStack(spacing: 16) {
                        filterButton
                        addButton
                    }
                }
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
                        ToolbarItem(placement: .navigationBarLeading) {
                            if selectedType != nil {
                                Button("filter.clear".localized) {
                                    withAnimation(DS.Animation.micro) {
                                        selectedType = nil
                                        showingFilters = false
                                        filterWorkDaysAsync()
                                    }
                                }
                                .foregroundStyle(.red)
                            }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
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
            filterWorkDaysAsync()
        }
        .onChange(of: selectedMonth) { _, _ in
            filterWorkDaysAsync()
        }
        .onChange(of: selectedYear) { _, _ in
            filterWorkDaysAsync()
        }
        .onChange(of: searchText) { _, _ in
            applySearchAndTypeFilterAsync()
        }
        .onChange(of: selectedType) { _, _ in
            applySearchAndTypeFilterAsync()
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
            .buttonStyle(.pressable)

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
                            .background(Color.blue.opacity(0.1), in: Capsule())
                    }
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
            .buttonStyle(.pressable)
        }
        .padding(.vertical, DS.Spacing.sm)
        .background(Color(.systemGroupedBackground))
    }

    private var searchAndFilterBar: some View {
        HStack(spacing: 10) {
            // Barre de recherche
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                if isSearching {
                    TextField("search.placeholder".localized, text: $searchText)
                        .autocorrectionDisabled(true)
                        .focused($isSearchFieldFocused)
                } else {
                    Button(action: {
                        withAnimation(DS.Animation.interactive) {
                            isSearching = true
                        }
                    }) {
                        Text("search.placeholder".localized)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }

                if isSearching {
                    Button(action: {
                        withAnimation(DS.Animation.interactive) {
                            searchText = ""
                            isSearching = false
                            isSearchFieldFocused = false
                            filterWorkDaysAsync() // Réinitialiser le filtre
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Bouton de filtre
            Button(action: {
                withAnimation(DS.Animation.interactive) {
                    showingFilters.toggle()
                }
            }) {
                Image(systemName: hasFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(.title3)
                    .foregroundColor(hasFilterActive ? .blue : .secondary)
            }
        }
        .padding(.horizontal)
    }

    private var workDaysList: some View {
        List {
            ForEach(Array(groupedWorkDays.keys.sorted(by: >)), id: \.self) { dateKey in
                if let days = groupedWorkDays[dateKey] {
                    Section(header: CustomSectionHeader(
                        date: formatSectionDate(dateKey),
                        isToday: isToday(dateKey),
                        isEditMode: isEditMode,
                        isSelected: selectedDates.contains(dateKey),
                        onToggleSelection: {
                            toggleDateSelection(dateKey, days)
                        }
                    )) {
                        ForEach(days.sorted(by: { $0.date > $1.date })) { workDay in
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
                        }
                        
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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
                        selectedType = nil
                        showingFilters = false
                        filterWorkDaysAsync()
                }
            } else {
                    showAddWorkDayView = true
                }
            },
            iconColors: hasFilterActive ? [.orange, .red] : [.blue, .purple]
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
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
                .foregroundColor(hasFilterActive ? .blue : .secondary)
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
        filterTask?.cancel()
        isFilteringData = true

        filterTask = Task { @MainActor in
            guard !Task.isCancelled else { isFilteringData = false; return }
            let calendar = Calendar.current
            guard let startOfMonth = calendar.date(from: DateComponents(year: selectedYear, month: currentMonth, day: 1)),
                  let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
                isFilteringData = false
                return
            }

            do {
                // ✅ Prédicat SQL : filtré en base, pas en mémoire
                var descriptor = FetchDescriptor<WorkDay>(
                    predicate: #Predicate<WorkDay> { workDay in
                        workDay.date >= startOfMonth &&
                        workDay.date < endOfMonth
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )

                // ✅ propertiesToFetch : charge uniquement les champs utilisés dans la liste
                // Les champs non listés sont chargés à la demande (faulting automatique)
                descriptor.propertiesToFetch = [
                    \.id, \.date, \.typeRawValue, \.totalHours,
                    \.overtimeSeconds, \.bonusAmount, \.note,
                    \.startTime, \.endTime, \.breakDuration
                ]

                let filtered = try modelContext.fetch(descriptor)

                let totalHours = filtered.reduce(0.0) { $0 + $1.totalHours }
                let overtimeSeconds = filtered.reduce(0) { $0 + $1.overtimeSeconds }
                let totalBonus = filtered.reduce(0.0) { $0 + $1.bonusAmount }

                self.filteredWorkDays = filtered
                self.groupedWorkDays = Dictionary(grouping: filtered) { dayOnly(from: $0.date) }
                self.cachedMonthlyStats = (totalHours, overtimeSeconds, totalBonus)
                self.isFilteringData = false

                withAnimation(DS.Animation.appear) { self.animateList = true }

            } catch {
                AppLogger.error("WorkDays fetch failed", category: AppLogger.general, error: error)
                self.filteredWorkDays = []
                self.groupedWorkDays = [:]
                self.cachedMonthlyStats = (0, 0, 0)
                self.isFilteringData = false
            }
        }
    }
    
    /// Applique les filtres de recherche et de type
    private func applySearchAndTypeFilterAsync() {
        filterTask?.cancel()
        isFilteringData = true

        filterTask = Task { @MainActor in
            guard !Task.isCancelled else { isFilteringData = false; return }
            // Filtrer directement sur le thread principal
            let filtered = filterWorkDaysWithSearchAndType()
            
            // Mettre à jour l'UI
            self.filteredWorkDays = filtered
            self.groupedWorkDays = Dictionary(grouping: filtered) { dayOnly(from: $0.date) }
            self.isFilteringData = false
            
            // Animer l'apparition progressive des éléments
            withAnimation(DS.Animation.appear) {
                self.animateList = true
            }
        }
    }
    
    /// Filtre les WorkDays avec recherche et type - version synchrone
    private func filterWorkDaysWithSearchAndType() -> [WorkDay] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: DateComponents(year: selectedYear, month: currentMonth, day: 1)),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else {
            return []
        }

        do {
            let fetched: [WorkDay]
            if let selectedType {
                let selectedTypeRawValue = selectedType.rawValue
                let descriptor = FetchDescriptor<WorkDay>(
                    predicate: #Predicate<WorkDay> { workDay in
                        workDay.date >= startOfMonth &&
                        workDay.date < endOfMonth &&
                        workDay.typeRawValue == selectedTypeRawValue
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                fetched = try modelContext.fetch(descriptor)
            } else {
                let descriptor = FetchDescriptor<WorkDay>(
                    predicate: #Predicate<WorkDay> { workDay in
                        workDay.date >= startOfMonth &&
                        workDay.date < endOfMonth
                    },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                fetched = try modelContext.fetch(descriptor)
            }

            return fetched.filter { workDay in
                let matchesSearch = searchText.isEmpty ||
                    (workDay.note?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                    workDay.type.rawValue.localizedCaseInsensitiveContains(searchText)

                return matchesSearch
            }
        } catch {
            AppLogger.error("WorkDays search fetch failed", category: AppLogger.general, error: error)
            return []
        }
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
        StatsCache.shared.onWorkDayDeleted(workDay)
        modelContext.delete(workDay)
        
        // Sauvegarde du contexte
        do {
            try modelContext.save()
            
            // Actualiser la liste filtrée et le groupement
            let workDayID = workDay.id
            filteredWorkDays.removeAll { $0.id == workDayID }
            groupedWorkDays = Dictionary(grouping: filteredWorkDays) { dayOnly(from: $0.date) }
            
        } catch {
            ErrorManager.shared.handle(error, context: "DeleteWorkDay")
        }
    }
    
    /// Naviguer vers le mois précédent
    private func navigateToPreviousMonth() {
        let calendar = Calendar.current
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = previousMonth
            selectedYear = calendar.component(.year, from: previousMonth)
            animateList = false
        }
    }
    
    /// Naviguer vers le mois suivant
    private func navigateToNextMonth() {
        let calendar = Calendar.current
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = nextMonth
            selectedYear = calendar.component(.year, from: nextMonth)
            animateList = false
        }
    }
    
    /// Revenir au mois courant
    private func navigateToCurrentMonth() {
        let currentDate = Date()
        selectedMonth = currentDate
        selectedYear = Calendar.current.component(.year, from: currentDate)
        animateList = false
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
        selectedMonth.formatted(.dateTime.month(.wide).year())
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
                        .foregroundColor(isSelected ? .blue : .gray)
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
                    .foregroundColor(.blue)
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
                .foregroundColor(.white)
                .frame(width: DS.IconSize.inline, height: DS.IconSize.inline)
                .background(color, in: RoundedRectangle(cornerRadius: DS.IconRadius.inline))

            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
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
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                Text(type?.rawValue ?? "Tous les types")
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
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
