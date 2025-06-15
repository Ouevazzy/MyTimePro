import SwiftUI
import SwiftData
import UIKit

struct AddEditWorkDayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var workDay: WorkDay
    
    @State private var selectedType: WorkDayType = .work
    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var breakDuration: Date
    @State private var bonusAmount: Double = 0.0
    @State private var note: String = ""
    @State private var isNewWorkDay: Bool
    
    private let settings = UserSettings.shared
    
    init(workDay: WorkDay) {
        self.workDay = workDay
        _selectedType = State(initialValue: workDay.type)
        _date = State(initialValue: workDay.date)
        _isNewWorkDay = State(initialValue: workDay.id == UUID())
        
        // Utiliser les heures sauvegardées ou les heures existantes du workDay
        _startTime = State(initialValue: workDay.startTime ?? UserSettings.shared.lastStartTime)
        _endTime = State(initialValue: workDay.endTime ?? UserSettings.shared.lastEndTime)
        
        // Initialiser breakDuration
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: Date())
        _breakDuration = State(initialValue: calendar.date(byAdding: .second, value: Int(workDay.breakDuration), to: midnight) ?? Date())
        
        _bonusAmount = State(initialValue: workDay.bonusAmount)
    }
    
    var body: some View {
        Form {
            // Section Détails de la Journée
            Section {
                DatePicker("Date de l'entrée", selection: $date, displayedComponents: .date)
                
                Picker("Type de Journée", selection: $selectedType) {
                    ForEach(WorkDayType.allCases.filter { $0 != .training }, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                if selectedType == .work {
                    DatePicker("Heure de Début", selection: $startTime, displayedComponents: .hourAndMinute)
                        .onChange(of: startTime) { _, newValue in
                            if newValue > endTime {
                                endTime = newValue.addingTimeInterval(3600)
                            }
                            settings.updateLastUsedTimes(start: newValue, end: nil)
                        }
                    
                    DatePicker("Heure de Fin", selection: $endTime, displayedComponents: .hourAndMinute)
                        .onChange(of: endTime) { _, newValue in
                            if newValue < startTime {
                                startTime = newValue.addingTimeInterval(-3600)
                            }
                            settings.updateLastUsedTimes(start: nil, end: newValue)
                        }
                    
                    DatePicker("Temps de Pause", selection: $breakDuration, displayedComponents: .hourAndMinute)
                        .onChange(of: breakDuration) { _, _ in
                            updateWorkDay()
                        }
                        .datePickerStyle(.compact)
                }
            } header: {
                Text("DÉTAILS DE LA JOURNÉE")
            }
            
            // Section Bonus
            if selectedType == .work {
                Section {
                    TextField("Montant du Bonus", value: $bonusAmount, format: .number)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("BONUS")
                }
            }
            
            // Section Note
            Section {
                TextField("Note", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            } header: {
                Text("NOTE")
            }
        }
        .navigationTitle("Ajouter/Modifier Journée")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Annuler") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Enregistrer") {
                    saveWorkDay()
                }
                .disabled(!isFormValid())
            }
        }
        .onAppear {
            loadWorkDay()
        }
        .onChange(of: selectedType) { _, _ in
            // Force le recalcul des heures lors du changement de type
            workDay.type = selectedType
            updateWorkDay()
        }
    }
    
    private func loadWorkDay() {
        let workDayID = workDay.id
        let predicate: Predicate<WorkDay> = #Predicate { $0.id == workDayID }
        let descriptor = FetchDescriptor<WorkDay>(predicate: predicate)
        
        do {
            let fetchedWorkDays = try modelContext.fetch(descriptor)
            isNewWorkDay = fetchedWorkDays.isEmpty
        } catch {
            print("Failed to fetch WorkDay: \(error.localizedDescription)")
            isNewWorkDay = true
        }
        
        selectedType = workDay.type
        date = workDay.date
        
        if workDay.type == .work {
            startTime = workDay.startTime ?? UserSettings.shared.lastStartTime
            endTime = workDay.endTime ?? UserSettings.shared.lastEndTime
            
            if workDay.breakDuration > 0 {
                let calendar = Calendar.current
                let midnight = calendar.startOfDay(for: Date())
                breakDuration = calendar.date(byAdding: .second, value: Int(workDay.breakDuration), to: midnight) ?? Date()
            }
            bonusAmount = workDay.bonusAmount
        } else {
            startTime = Date()
            endTime = Date()
            breakDuration = Calendar.current.date(byAdding: .hour, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
            bonusAmount = 0
        }
        
        note = workDay.note ?? ""
    }
    
    private func updateWorkDay() {
        workDay.date = date
        workDay.type = selectedType
        
        if selectedType == .work {
            workDay.updateData(
                startTime: startTime,
                endTime: endTime,
                breakDuration: breakDuration.timeIntervalSince(Calendar.current.startOfDay(for: breakDuration))
            )
            workDay.bonusAmount = bonusAmount
        } else {
            workDay.updateData(
                startTime: nil,
                endTime: nil,
                breakDuration: 0
            )
            workDay.bonusAmount = 0
        }
    }
    
    private func saveWorkDay() {
        updateWorkDay()
        workDay.note = note
        
        do {
            if isNewWorkDay {
                modelContext.insert(workDay)
            }
            
            // Sauvegarder les dernières heures utilisées
            settings.updateLastUsedTimes(start: startTime, end: endTime)
            
            try modelContext.save()
        } catch {
            print("Failed to save WorkDay: \(error.localizedDescription)")
        }
        
        dismiss()
    }
    
    private func isFormValid() -> Bool {
        if selectedType == .work {
            return endTime > startTime && bonusAmount >= 0
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
