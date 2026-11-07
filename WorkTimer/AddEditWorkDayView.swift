import SwiftUI
import SwiftData
import UIKit

enum WorkDayFormValidationIssue: Equatable {
    case dateTooFarInFuture
    case dateTooFarInPast
    case noteTooLong
    case negativeBonus
    case missingTimes
    case invalidDuration
    case breakTooLong
    case noNetHours

    var localizedMessage: String {
        switch self {
        case .dateTooFarInFuture:
            return "workDay.validation.dateTooFarInFuture".localized
        case .dateTooFarInPast:
            return "workDay.validation.dateTooFarInPast".localized
        case .noteTooLong:
            return "workDay.validation.noteTooLong".localized
        case .negativeBonus:
            return "workDay.validation.negativeBonus".localized
        case .missingTimes:
            return "workDay.validation.missingTimes".localized
        case .invalidDuration:
            return "workDay.validation.invalidDuration".localized
        case .breakTooLong:
            return "workDay.validation.breakTooLong".localized
        case .noNetHours:
            return "workDay.validation.noNetHours".localized
        }
    }
}

struct WorkDayFormDraft {
    let date: Date
    let type: WorkDayType
    let startTime: Date
    let endTime: Date
    let breakDuration: Date
    let bonusAmount: Double
    let note: String
    /// La fin tombe le lendemain de `date` (session de nuit).
    var endsNextDay = false
    var calendar = Calendar.current

    var normalizedDate: Date {
        calendar.startOfDay(for: date)
    }

    var trimmedNote: String? {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var breakSeconds: TimeInterval {
        breakDuration.timeIntervalSince(calendar.startOfDay(for: breakDuration))
    }

    var normalizedStartTime: Date? {
        guard type.isWorkDay else { return nil }
        return Self.time(startTime, on: normalizedDate, calendar: calendar)
    }

    var normalizedEndTime: Date? {
        guard type.isWorkDay else { return nil }
        let endDay = endsNextDay
            ? calendar.date(byAdding: .day, value: 1, to: normalizedDate) ?? normalizedDate
            : normalizedDate
        return Self.time(endTime, on: endDay, calendar: calendar)
    }

    var netWorkedSeconds: TimeInterval? {
        guard let start = normalizedStartTime, let end = normalizedEndTime else { return nil }
        return max(0, end.timeIntervalSince(start) - breakSeconds)
    }

    var isValid: Bool {
        validationIssue == nil
    }

    var validationIssue: WorkDayFormValidationIssue? {
        let maxFutureDate = calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date.distantFuture
        guard normalizedDate <= maxFutureDate else { return .dateTooFarInFuture }

        let minPastDate = calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date.distantPast
        guard normalizedDate >= minPastDate else { return .dateTooFarInPast }

        guard note.count <= 500 else { return .noteTooLong }

        if type.isWorkDay {
            guard bonusAmount >= 0 else { return .negativeBonus }
            guard let start = normalizedStartTime, let end = normalizedEndTime else { return .missingTimes }

            let duration = end.timeIntervalSince(start)
            guard duration > 0 && duration <= 24 * 3600 else { return .invalidDuration }
            guard breakSeconds >= 0 && breakSeconds <= duration else { return .breakTooLong }
            guard let netWorkedSeconds, netWorkedSeconds > 0 else { return .noNetHours }
        }

        return nil
    }

    func makeValidatedWorkDay() -> WorkDay? {
        guard isValid else { return nil }

        let candidate = WorkDay(date: normalizedDate, type: type)
        apply(to: candidate)

        guard candidate.isValid else { return nil }
        guard !candidate.type.isWorkDay || candidate.totalHours > 0 else { return nil }
        return candidate
    }

    func apply(to workDay: WorkDay) {
        workDay.date = normalizedDate
        workDay.type = type
        workDay.note = trimmedNote

        if type.isWorkDay {
            workDay.updateData(
                startTime: normalizedStartTime,
                endTime: normalizedEndTime,
                breakDuration: breakSeconds
            )
            workDay.bonusAmount = bonusAmount
        } else {
            workDay.updateData(startTime: nil, endTime: nil, breakDuration: 0)
            workDay.bonusAmount = 0
        }
    }

    static func time(_ time: Date, on date: Date, calendar: Calendar = .current) -> Date? {
        let components = calendar.dateComponents([.hour, .minute, .second], from: time)
        return calendar.date(
            bySettingHour: components.hour ?? 0,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            of: date
        )
    }
}

struct AddEditWorkDayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workDay: WorkDay

    // MARK: - State Properties (copie locale — le workDay n'est muté qu'au save)
    @State private var selectedType: WorkDayType = .work
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var endsNextDay: Bool
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
        let startTime = workDay.startTime ?? UserSettings.shared.lastStartTime
        let endTime = workDay.endTime ?? UserSettings.shared.lastEndTime
        _startTime = State(initialValue: WorkDayFormDraft.time(startTime, on: workDay.date) ?? startTime)
        _endTime = State(initialValue: WorkDayFormDraft.time(endTime, on: workDay.date) ?? endTime)
        _endsNextDay = State(initialValue: Self.endsOnLaterDay(workDay))

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
                        startTime = WorkDayFormDraft.time(settings.lastStartTime, on: date) ?? settings.lastStartTime
                        endTime = WorkDayFormDraft.time(settings.lastEndTime, on: date) ?? settings.lastEndTime
                        endsNextDay = false
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
                                if !endsNextDay && newValue > endTime {
                                    withAnimation {
                                        endTime = newValue.addingTimeInterval(3600)
                                    }
                                }
                            }

                        DatePicker("workDay.endTime".localized, selection: $endTime, displayedComponents: .hourAndMinute)
                            .onChange(of: endTime) { _, newValue in
                                if !endsNextDay && newValue < startTime {
                                    withAnimation {
                                        startTime = newValue.addingTimeInterval(-3600)
                                    }
                                }
                            }

                        Toggle("workDay.endsNextDay".localized, isOn: $endsNextDay)

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
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, DS.Spacing.sm)
                                    .padding(.vertical, DS.Spacing.xs)
                                    .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: DS.Radius.small))
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

            if let validationIssue = currentDraft.validationIssue {
                Section {
                    Label(validationIssue.localizedMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("workDay.validationMessage")
                } header: {
                    Label("workDay.validation.title".localized, systemImage: "checklist")
                }
            }
            
            // Section résumé (pour journée de travail)
            if selectedType == .work && (endsNextDay || startTime < endTime) {
                Section {
                    HStack {
                        Label("workDay.totalDuration".localized, systemImage: "clock")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(calculatedDuration)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                    if settings.isHourlyRateEnabled {
                        HStack {
                            Label("stats.earnings".localized, systemImage: "banknote")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(settings.formatCurrency(calculatedEarnings))
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Label("workDay.summary".localized, systemImage: "chart.bar")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(isNewWorkDay ? "workDay.new".localized : "workDay.edit".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("action.cancel".localized) {
                    focusedField = nil
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("action.save".localized) {
                    focusedField = nil
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
        .onChange(of: date) { _, newDate in
            alignDisplayedTimes(with: newDate)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedType)
        .withErrorHandling()
    }
    
    // MARK: - Computed Properties
    private var calculatedDuration: String {
        let netDuration = currentDraft.netWorkedSeconds ?? 0
        
        let hours = Int(netDuration) / 3600
        let minutes = (Int(netDuration) % 3600) / 60
        return String(format: "%dh%02d", hours, minutes)
    }

    /// Rémunération estimée du brouillon courant : heures nettes × taux horaire + bonus.
    private var calculatedEarnings: Double {
        let hours = (currentDraft.netWorkedSeconds ?? 0) / 3600.0
        return hours * settings.hourlyRate + bonusAmount
    }

    private var currentDraft: WorkDayFormDraft {
        WorkDayFormDraft(
            date: date,
            type: selectedType,
            startTime: startTime,
            endTime: endTime,
            breakDuration: breakDuration,
            bonusAmount: bonusAmount,
            note: note,
            endsNextDay: endsNextDay
        )
    }

    private static func endsOnLaterDay(_ workDay: WorkDay) -> Bool {
        guard let end = workDay.endTime else { return false }
        return !Calendar.current.isDate(end, inSameDayAs: workDay.date)
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
            let loadedStart = workDay.startTime ?? UserSettings.shared.lastStartTime
            let loadedEnd = workDay.endTime ?? UserSettings.shared.lastEndTime
            startTime = WorkDayFormDraft.time(loadedStart, on: date) ?? loadedStart
            endTime = WorkDayFormDraft.time(loadedEnd, on: date) ?? loadedEnd
            endsNextDay = Self.endsOnLaterDay(workDay)

            let calendar = Calendar.current
            let midnight = calendar.startOfDay(for: Date())
            // Utiliser la pause existante si l'entrée a des données, sinon la dernière pause sauvegardée
            let breakSeconds = (workDay.startTime != nil) ? workDay.breakDuration : UserSettings.shared.lastBreakDuration
            breakDuration = calendar.date(byAdding: .second, value: Int(breakSeconds), to: midnight) ?? Date()

            bonusAmount = workDay.bonusAmount
        } else {
            // Pour les types non-travail, utiliser des valeurs par défaut
            let calendar = Calendar.current
            startTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: date) ?? Date()
            endTime = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: date) ?? Date()
            breakDuration = calendar.date(byAdding: .hour, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
            bonusAmount = 0
        }
        
        note = workDay.note ?? ""
    }
    
    private func saveWorkDay() {
        let draft = currentDraft
        let previousDate = workDay.date
        let previousType = workDay.type

        guard draft.makeValidatedWorkDay() != nil else {
            ErrorManager.shared.handleValidationError("Les données saisies ne sont pas valides")
            return
        }

        // Appliquer toutes les valeurs locales au workDay uniquement après validation.
        draft.apply(to: workDay)

        do {
            if isNewWorkDay {
                modelContext.insert(workDay)
            }

            _ = try WorkDay.reconcileDailyOvertime(
                in: modelContext,
                for: [previousDate, workDay.date]
            )

            try modelContext.save()

            if selectedType.isWorkDay {
                settings.updateLastUsedTimes(
                    start: draft.normalizedStartTime,
                    end: draft.normalizedEndTime,
                    breakDuration: draft.breakSeconds
                )
            }

            StatsCache.shared.onWorkDayChanged(workDay, previousDate: previousDate, previousType: previousType)
            SiriSummaryCacheService().refresh(using: modelContext)
            Haptic.notification(.success)
        } catch {
            modelContext.rollback()
            ErrorManager.shared.handle(error, context: "SaveWorkDay")
            return
        }

        dismiss()
    }
    
    private func isFormValid() -> Bool {
        currentDraft.isValid
    }

    private func alignDisplayedTimes(with selectedDate: Date) {
        startTime = WorkDayFormDraft.time(startTime, on: selectedDate) ?? startTime
        endTime = WorkDayFormDraft.time(endTime, on: selectedDate) ?? endTime
    }
}

#Preview {
    NavigationStack {
        AddEditWorkDayView(workDay: WorkDay())
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}
