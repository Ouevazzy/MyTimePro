import SwiftUI
import SwiftData
import UIKit

struct AddEditWorkDayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workDay: WorkDay

    // MARK: - State Properties (copie locale — le workDay n'est muté qu'au save)
    @State private var selectedType: WorkDayType = .work
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var breakDuration: Date
    @State private var bonusAmount: Double = 0.0
    @State private var note: String = ""
    @State private var isNewWorkDay: Bool
    @State private var showTypeAnimation = false

    // MARK: - Focus State
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case bonus, note
    }

    private let settings = UserSettings.shared

    // MARK: - Initialization
    init(workDay: WorkDay) {
        self.workDay = workDay
        _selectedType = State(initialValue: workDay.type)
        _date = State(initialValue: workDay.date)
        
        // Correction: Vérifier si les données sont vides plutôt que l'UUID
        // Un nouveau WorkDay n'a pas d'heure de début et a 0 heures totales
        _isNewWorkDay = State(initialValue: workDay.startTime == nil && workDay.totalHours == 0 && workDay.type == .work)
        
        // Utiliser les heures sauvegardées ou les heures existantes du workDay
        _startTime = State(initialValue: workDay.startTime ?? UserSettings.shared.lastStartTime)
        _endTime = State(initialValue: workDay.endTime ?? UserSettings.shared.lastEndTime)
        
        // Initialiser breakDuration : utiliser la valeur existante ou la dernière pause sauvegardée
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: Date())
        let breakSeconds = (workDay.startTime != nil) ? workDay.breakDuration : UserSettings.shared.lastBreakDuration
        _breakDuration = State(initialValue: calendar.date(byAdding: .second, value: Int(breakSeconds), to: midnight) ?? Date())
        
        _bonusAmount = State(initialValue: workDay.bonusAmount)
        _note = State(initialValue: workDay.note ?? "")
    }
    
    // MARK: - Body
    var body: some View {
        Form {
            // Section Détails de la Journée
            Section {
                DatePicker("workDay.date".localized, selection: $date, displayedComponents: .date)
                
                // Picker avec animation de type
                Picker("workDay.type".localized, selection: $selectedType) {
                    ForEach(WorkDayType.allCases.filter { $0 != .training }, id: \.self) { type in
                        Label(type.localizedName, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .onChange(of: selectedType) { oldValue, newValue in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showTypeAnimation = true
                    }
                    // Reset time fields when switching away from work type
                    if oldValue == .work && newValue != .work {
                        bonusAmount = 0
                    } else if oldValue != .work && newValue == .work {
                        // Restore last used times when switching back to work
                        startTime = settings.lastStartTime
                        endTime = settings.lastEndTime
                        let calendar = Calendar.current
                        let midnight = calendar.startOfDay(for: Date())
                        breakDuration = calendar.date(byAdding: .second, value: Int(settings.lastBreakDuration), to: midnight) ?? Date()
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        showTypeAnimation = false
                    }
                }
                
                if selectedType == .work {
                    // Heures de travail avec animations
                    Group {
                    DatePicker("workDay.startTime".localized, selection: $startTime, displayedComponents: .hourAndMinute)
                        .onChange(of: startTime) { _, newValue in
                            if newValue > endTime {
                                    withAnimation {
                                endTime = newValue.addingTimeInterval(3600)
                            }
                                }
                            settings.updateLastUsedTimes(start: newValue, end: nil)
                        }
                    
                    DatePicker("workDay.endTime".localized, selection: $endTime, displayedComponents: .hourAndMinute)
                        .onChange(of: endTime) { _, newValue in
                            if newValue < startTime {
                                    withAnimation {
                                startTime = newValue.addingTimeInterval(-3600)
                            }
                                }
                            settings.updateLastUsedTimes(start: nil, end: newValue)
                        }
                    
                    DatePicker("workDay.breakDuration".localized, selection: $breakDuration, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } header: {
                Label("workDay.details".localized, systemImage: "info.circle")
            }
            
            // Section Bonus - avec animation
            if selectedType == .work {
                Section {
                    HStack {
                        TextField("workDay.bonus".localized, value: $bonusAmount, format: .currency(code: Locale.current.currency?.identifier ?? "EUR"))
                        .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .bonus)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .note
                            }
                        
                        // Boutons rapides pour bonus
                        if bonusAmount == 0 {
                            HStack(spacing: 8) {
                                ForEach([10.0, 25.0, 50.0], id: \.self) { amount in
                                    Button("+\(Int(amount))") {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            bonusAmount = amount
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                } header: {
                    Label("workDay.bonus".localized, systemImage: "dollarsign.circle")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Section Note
            Section {
                TextField("workDay.note".localized, text: $note, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .note)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                    }
            } header: {
                Label("workDay.note".localized, systemImage: "note.text")
            }
            
            // Section résumé (pour journée de travail)
            if selectedType == .work && startTime < endTime {
                Section {
                    HStack {
                        Label("workDay.totalDuration".localized, systemImage: "clock")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(calculatedDuration)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                } header: {
                    Label("workDay.summary".localized, systemImage: "chart.bar")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isNewWorkDay ? "workDay.new".localized : "workDay.edit".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("action.cancel".localized) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("action.save".localized) {
                    Haptic.notification(.success)
                    saveWorkDay()
                }
                .fontWeight(.semibold)
                .disabled(!isFormValid())
            }
            
            // Toolbar pour le clavier
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("action.done".localized) {
                    focusedField = nil
                }
            }
        }
        .onAppear {
            loadWorkDay()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedType)
        .withErrorHandling()
    }
    
    // MARK: - Computed Properties
    private var calculatedDuration: String {
        let duration = endTime.timeIntervalSince(startTime)
        let breakSeconds = breakDuration.timeIntervalSince(Calendar.current.startOfDay(for: breakDuration))
        let netDuration = max(0, duration - breakSeconds)
        
        let hours = Int(netDuration) / 3600
        let minutes = (Int(netDuration) % 3600) / 60
        return String(format: "%dh%02d", hours, minutes)
    }
    
    // MARK: - Private Methods
    private func loadWorkDay() {
        let workDayID = workDay.id
        let predicate: Predicate<WorkDay> = #Predicate { $0.id == workDayID }
        let descriptor = FetchDescriptor<WorkDay>(predicate: predicate)

        do {
            let fetchedWorkDays = try modelContext.fetch(descriptor)
            let existsInDB = !fetchedWorkDays.isEmpty
            let hasData = workDay.startTime != nil || workDay.totalHours > 0 || workDay.type != .work
            isNewWorkDay = !existsInDB && !hasData
        } catch {
            AppLogger.error("Failed to fetch WorkDay", category: AppLogger.general, error: error)
            isNewWorkDay = true
        }
        
        selectedType = workDay.type
        date = workDay.date
        
        if workDay.type == .work {
            startTime = workDay.startTime ?? UserSettings.shared.lastStartTime
            endTime = workDay.endTime ?? UserSettings.shared.lastEndTime

            let calendar = Calendar.current
            let midnight = calendar.startOfDay(for: Date())
            // Utiliser la pause existante si l'entrée a des données, sinon la dernière pause sauvegardée
            let breakSeconds = (workDay.startTime != nil) ? workDay.breakDuration : UserSettings.shared.lastBreakDuration
            breakDuration = calendar.date(byAdding: .second, value: Int(breakSeconds), to: midnight) ?? Date()

            bonusAmount = workDay.bonusAmount
        } else {
            // Pour les types non-travail, utiliser des valeurs par défaut
            let calendar = Calendar.current
            startTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
            endTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
            breakDuration = calendar.date(byAdding: .hour, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
            bonusAmount = 0
        }
        
        note = workDay.note ?? ""
    }
    
    private func saveWorkDay() {
        // Validation avant sauvegarde
        guard isFormValid() else {
            ErrorManager.shared.handleValidationError("Les données saisies ne sont pas valides")
            return
        }

        // Appliquer toutes les valeurs locales au workDay uniquement maintenant
        workDay.date = date
        workDay.type = selectedType
        workDay.note = note.isEmpty ? nil : note

        if selectedType == .work {
            let breakSeconds = breakDuration.timeIntervalSince(Calendar.current.startOfDay(for: breakDuration))
            workDay.updateData(
                startTime: startTime,
                endTime: endTime,
                breakDuration: breakSeconds
            )
            workDay.bonusAmount = bonusAmount
        } else {
            workDay.updateData(startTime: nil, endTime: nil, breakDuration: 0)
            workDay.bonusAmount = 0
        }

        // Validation finale de l'objet
        guard workDay.isValid else {
            ErrorManager.shared.handleValidationError("Les données de la journée ne sont pas valides")
            return
        }

        // ⚠️ Sécurité anti-entrées fantômes : ne jamais sauvegarder une entrée travail avec 0h
        if workDay.type.isWorkDay && workDay.totalHours == 0 {
            AppLogger.warning("Tentative de sauvegarde d'une entrée travail avec 0h — annulée", category: AppLogger.data)
            ErrorManager.shared.handleValidationError("Impossible de sauvegarder une entrée avec 0h de travail")
            return
        }

        do {
            if isNewWorkDay {
                modelContext.insert(workDay)
            }

            let breakSeconds = breakDuration.timeIntervalSince(Calendar.current.startOfDay(for: breakDuration))
            settings.updateLastUsedTimes(start: startTime, end: endTime, breakDuration: breakSeconds)

            StatsCache.shared.onWorkDayChanged(workDay)
            try modelContext.save()
            Haptic.notification(.success)
        } catch {
            ErrorManager.shared.handle(error, context: "SaveWorkDay")
            return
        }

        dismiss()
    }
    
    private func isFormValid() -> Bool {
        if selectedType == .work {
            // Validation des heures : fin > début
            guard endTime > startTime else { return false }
            
            // Validation du montant bonus : positif
            guard bonusAmount >= 0 else { return false }
            
            // Validation des heures raisonnables (max 24h de travail)
            let duration = endTime.timeIntervalSince(startTime)
            guard duration <= 24 * 3600 else { return false }
            
            // Validation de la pause : positive et <= durée travaillée
            let breakSeconds = breakDuration.timeIntervalSince(Calendar.current.startOfDay(for: breakDuration))
            guard breakSeconds >= 0 && breakSeconds <= duration else { return false }
        }
        
        // Validation de la date : pas trop dans le futur (max 1 an)
        let maxFutureDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date.distantFuture
        guard date <= maxFutureDate else { return false }
        
        // Validation de la date : pas trop dans le passé (max 10 ans)
        let minPastDate = Calendar.current.date(byAdding: .year, value: -10, to: Date()) ?? Date.distantPast
        guard date >= minPastDate else { return false }
        
        // Validation de la note : longueur raisonnable (max 500 caractères)
        if note.count > 500 {
            return false
        }
        
        return true
    }
}

#Preview {
    NavigationStack {
        AddEditWorkDayView(workDay: WorkDay())
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}
