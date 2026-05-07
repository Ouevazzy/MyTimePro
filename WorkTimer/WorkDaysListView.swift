import SwiftUI
import SwiftData

struct WorkDaysListView: View {
    // MARK: - Environment & Properties
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    // Requête optimisée avec un prédicat basique
    @Query(sort: \WorkDay.date, order: .reverse) private var allWorkDays: [WorkDay]
    
    // MARK: - State
    @State private var showAddWorkDayView = false
    @State private var selectedWorkDay: WorkDay?
    @State private var selectedMonth = Date()
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
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
    @State private var filteredWorkDays: [WorkDay] = []
    @State private var isFilteringData = false
    @State private var cachedMonthlyStats: (totalHours: Double, overtimeSeconds: Int, totalBonus: Double) = (0, 0, 0)
    
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
    
    private var filteredAndGroupedWorkDays: [Date: [WorkDay]] {
        let result = Dictionary(grouping: filteredWorkDays) { workDay in
            return dayOnly(from: workDay.date)
        }
        return result
    }
    
    private var hasFilterActive: Bool {
        !searchText.isEmpty || selectedType != nil
    }
    
    private var noResults: Bool {
        filteredAndGroupedWorkDays.isEmpty
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
                ProgressView("Chargement...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if noResults {
                emptyStateView
            } else {
                workDaysList
            }
        }
        .navigationTitle("Journées de Travail")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !isEditMode {
                    Button(action: {
                        withAnimation {
                            isEditMode = true
                        }
                    }) {
                        Text("Sélectionner")
                    }
                } else {
                    Button(action: {
                        withAnimation {
                            isEditMode = false
                            selectedWorkDays.removeAll()
                            selectedDates.removeAll()
                        }
                    }) {
                        Text("Annuler")
                    }
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                if isEditMode && !selectedWorkDays.isEmpty {
                    // Supprimer
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Label("Supprimer", systemImage: "trash")
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
        .alert(isPresented: $showErrorAlert) {
            Alert(title: Text("Erreur"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
        .alert("Confirmer la suppression", isPresented: $showingDeleteConfirmation) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                performBatchDelete()
            }
        } message: {
            Text("Êtes-vous sûr de vouloir supprimer \(selectedWorkDays.count) journée\(selectedWorkDays.count > 1 ? "s" : "") ?")
        }
        .overlay {
            if showingFilters {
                typeFilterOverlay
            }
        }
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
        .background(Color(.systemGroupedBackground))
    }
    
    private var searchAndFilterBar: some View {
        HStack(spacing: 10) {
            // Barre de recherche
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                if isSearching {
                    TextField("Rechercher...", text: $searchText)
                        .autocorrectionDisabled(true)
                } else {
                    Button(action: {
                        withAnimation {
                            isSearching = true
                        }
                    }) {
                        Text("Rechercher...")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                
                if isSearching {
                    Button(action: {
                        withAnimation {
                            searchText = ""
                            isSearching = false
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
                withAnimation {
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
            ForEach(Array(filteredAndGroupedWorkDays.keys.sorted(by: >)), id: \.self) { dateKey in
                if let days = filteredAndGroupedWorkDays[dateKey] {
                    Section(header: CustomSectionHeader(
                        date: formatSectionDate(dateKey),
                        isToday: isToday(dateKey),
                        isEditMode: isEditMode,
                        isSelected: selectedDates.contains(dateKey),
                        onToggleSelection: {
                            toggleDateSelection(dateKey, days)
                        }
                    )) {
                        // Limiter à 10 jours maximum par section pour optimiser le rendu
                        let visibleDays = days.prefix(10)
                        ForEach(visibleDays.sorted(by: { $0.date > $1.date })) { workDay in
                            WorkDayRow(
                                workDay: workDay,
                                isSelected: selectedWorkDays.contains(workDay.id),
                                isEditMode: isEditMode
                            )
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
                                    withAnimation {
                                        deleteWorkDay(workDay)
                                    }
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                        
                        // Afficher un bouton "Voir plus" si nécessaire
                        if days.count > 10 {
                            Button("Voir \(days.count - 10) autres...") {
                                // Logique pour voir plus - pourrait ouvrir une nouvelle vue
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.blue)
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
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: hasFilterActive ? "text.magnifyingglass" : "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(.blue.opacity(0.6))
            
            Text(hasFilterActive ? "Aucun résultat trouvé" : "Aucune journée pour ce mois")
                .font(.headline)
            
            if hasFilterActive {
                Button(action: {
                    withAnimation {
                        searchText = ""
                        selectedType = nil
                        showingFilters = false
                        filterWorkDaysAsync()
                    }
                }) {
                    Text("Effacer les filtres")
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            } else {
                Button(action: {
                    showAddWorkDayView = true
                }) {
                    Text("Ajouter une journée")
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
            }
            
            Spacer()
        }
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
            withAnimation {
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
    
    private var typeFilterOverlay: some View {
        VStack(spacing: 0) {
            // Fond semi-transparent
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showingFilters = false
                    }
                }
            
            // Panneau de filtre
            VStack(spacing: 15) {
                HStack {
                    Text("Filtrer par type")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            showingFilters = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.title3)
                    }
                }
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 5) {
                        // Option pour "Tous les types"
                        TypeFilterButton(
                            type: nil,
                            selectedType: $selectedType,
                            icon: "list.bullet",
                            color: .gray
                        ) {
                            withAnimation {
                                showingFilters = false
                            }
                        }
                        
                        // Options pour chaque type
                        ForEach(WorkDayType.allCases, id: \.self) { type in
                TypeFilterButton(
                                type: type,
                                selectedType: $selectedType,
                                icon: type.icon,
                                color: type.color
                            ) {
                                withAnimation {
                                    showingFilters = false
                                }
                            }
                        }
                    }
                }
                
                // Bouton pour effacer le filtre
                if selectedType != nil {
                    Button(action: {
                        withAnimation {
                            selectedType = nil
                            showingFilters = false
                            filterWorkDaysAsync()
                        }
                    }) {
                        Text("Effacer le filtre")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 0)
            .padding()
            .transition(.move(edge: .bottom))
        }
    }
    
    // MARK: - Helper Methods
    
    /// Filtre les workDays sur le mois/année sélectionnés de manière asynchrone pour éviter de bloquer l'UI
    private func filterWorkDaysAsync() {
        isFilteringData = true
        
        Task { @MainActor in
            // Exécuter le filtrage sur le thread principal pour éviter les problèmes Sendable
            let calendar = Calendar.current
            guard let startOfMonth = calendar.date(from: DateComponents(year: selectedYear, month: currentMonth, day: 1)),
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
                isFilteringData = false
                return
            }
            
            // Filtrer directement sur le thread principal
            let filtered = allWorkDays.filter { workDay in
                workDay.date >= startOfMonth && workDay.date <= endOfMonth && !workDay.isDeleted
            }
            
            // Calculer les statistiques
            let totalHours = filtered.reduce(0) { $0 + $1.totalHours }
            let overtimeSeconds = filtered.reduce(0) { $0 + $1.overtimeSeconds }
            let totalBonus = filtered.reduce(0) { $0 + $1.bonusAmount }
            let stats = (totalHours, overtimeSeconds, totalBonus)
            
            // Mettre à jour l'UI
            self.filteredWorkDays = filtered
            self.cachedMonthlyStats = stats
            self.isFilteringData = false
            
            // Animer l'apparition progressive des éléments
            withAnimation(.easeOut) {
                self.animateList = true
            }
        }
    }
    
    /// Applique les filtres de recherche et de type
    private func applySearchAndTypeFilterAsync() {
        isFilteringData = true
        
        Task { @MainActor in
            // Filtrer directement sur le thread principal
            let filtered = filterWorkDaysWithSearchAndType()
            
            // Mettre à jour l'UI
            self.filteredWorkDays = filtered
            self.isFilteringData = false
            
            // Animer l'apparition progressive des éléments
            withAnimation(.easeOut) {
                self.animateList = true
            }
        }
    }
    
    /// Filtre les WorkDays avec recherche et type - version synchrone
    private func filterWorkDaysWithSearchAndType() -> [WorkDay] {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: DateComponents(year: selectedYear, month: currentMonth, day: 1)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return []
        }
        
        return allWorkDays.filter { workDay in
            // Filtrer par mois/année
            let isInSelectedMonth = workDay.date >= startOfMonth && workDay.date <= endOfMonth && !workDay.isDeleted
            
            // Si pas dans le mois sélectionné, exclure immédiatement
            guard isInSelectedMonth else { return false }
            
            // Filtrage supplémentaire par recherche et type
            let matchesSearch = searchText.isEmpty ||
                             (workDay.note?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                             workDay.type.rawValue.localizedCaseInsensitiveContains(searchText)
            
            let matchesType = selectedType == nil || workDay.type == selectedType
            
            return matchesSearch && matchesType
        }
    }
    
    /// Gère la sélection/désélection d'un workDay
    private func toggleSelection(for workDay: WorkDay) {
        if selectedWorkDays.contains(workDay.id) {
            selectedWorkDays.remove(workDay.id)
            // Vérifier si nous devons aussi retirer la date du Set selectedDates
            let dayDate = dayOnly(from: workDay.date)
            if let daysForDate = filteredAndGroupedWorkDays[dayDate] {
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
            if let daysForDate = filteredAndGroupedWorkDays[dayDate] {
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
        // Exécuter sur le thread principal pour éviter les problèmes de concurrence
        // Récupérer les WorkDays à supprimer
        let workDaysToDelete = filteredWorkDays.filter { selectedWorkDays.contains($0.id) }
        
        // Supprimer chaque WorkDay
        for workDay in workDaysToDelete {
            // Suppression locale
            modelContext.delete(workDay)
            
            // Suppression CloudKit si nécessaire - en tâche de fond
            if let recordID = workDay.cloudKitRecordID {
                Task {
                    await CloudService.shared.deleteRecord(withID: recordID)
                }
            }
        }
        
        // Sauvegarde du contexte
        do {
            try modelContext.save()
            
            // Réinitialiser la sélection et quitter le mode édition
            withAnimation {
                selectedWorkDays.removeAll()
                selectedDates.removeAll()
                isEditMode = false
            }
            
            // Réactualiser la liste après suppression
            filterWorkDaysAsync()
            
        } catch {
            errorMessage = "Erreur lors de la suppression multiple : \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    /// Supprime un WorkDay
    private func deleteWorkDay(_ workDay: WorkDay) {
        // Suppression locale immédiate pour améliorer la réactivité de l'interface
        modelContext.delete(workDay)
        
        // Suppression sur iCloud en tâche de fond
        if let recordID = workDay.cloudKitRecordID {
            Task {
                await CloudService.shared.deleteRecord(withID: recordID)
            }
        }
        
        // Sauvegarde du contexte
        do {
            try modelContext.save()
            
            // Actualiser la liste filtrée
            let workDayID = workDay.id
            filteredWorkDays.removeAll { $0.id == workDayID }
            
        } catch {
            errorMessage = "Erreur lors de la suppression : \(error.localizedDescription)"
            showErrorAlert = true
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
                Text("Aujourd'hui")
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

struct WorkDayRow: View {
    let workDay: WorkDay
    var isSelected: Bool = false
    var isEditMode: Bool = false
    
    var body: some View {
        HStack {
            if isEditMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
                    .padding(.trailing, 4)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Ligne principale avec type et heures
                HStack(spacing: 8) {
                    Image(systemName: workDay.type.icon)
                        .foregroundColor(workDay.type.color)
                    
                    if workDay.type == .work {
                        Text(workDay.formattedTotalHours)
                            .foregroundColor(.primary)
                    } else {
                        Text(workDay.type.rawValue)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    if workDay.type == .work && workDay.overtimeSeconds != 0 {
                        Text(workDay.formattedOvertimeHours)
                            .foregroundColor(workDay.overtimeSeconds > 0 ? .green : .red)
                            .font(.callout)
                    }
                    
                    if workDay.bonusAmount > 0 {
                        Text("+" + String(format: "%.0f", workDay.bonusAmount))
                            .foregroundColor(.orange)
                            .font(.callout)
                    }
                }
                
                // Affichage de la note si elle existe
                if let note = workDay.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}

struct MonthlyStatsHeader: View {
    let stats: (totalHours: Double, overtimeSeconds: Int, totalBonus: Double)
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatItem(
                    title: "Heures",
                    value: WorkTimeCalculations.formattedTimeInterval(stats.totalHours * 3600),
                    icon: "clock.circle.fill",
                    color: .blue
                )
                
                StatItem(
                    title: "Heures supp.",
                    value: WorkTimeCalculations.formattedTimeInterval(Double(stats.overtimeSeconds)),
                    icon: "plusminus.circle.fill",
                    color: stats.overtimeSeconds >= 0 ? .green : .red
                )
                
                if stats.totalBonus > 0 {
                    StatItem(
                        title: "Bonus",
                        value: String(format: "%.0f", stats.totalBonus),
                        icon: "dollarsign.circle.fill",
                        color: .orange
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
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
            withAnimation {
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
