import SwiftUI
import SwiftData

struct AddEditWorkDayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    private let userSettings = UserSettings.shared
    
    var workDay: WorkDay

    @State private var date: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var breakDuration = 60.0
    @State private var type: WorkDayType = .work
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    init(workDay: WorkDay) {
        self.workDay = workDay
        _date = State(initialValue: workDay.date)
        _startTime = State(initialValue: workDay.startTime ?? Calendar.current.startOfDay(for: .now))
        _endTime = State(initialValue: workDay.endTime ?? Calendar.current.startOfDay(for: .now))
        _breakDuration = State(initialValue: Double(workDay.breakDuration / 60.0))
        _type = State(initialValue: workDay.type)
    }
    
    var body: some View {
        Form {
            typePicker
            datePicker
            if type.isWorkDay {
                timeSelectionView
            }
        }
        .navigationTitle(workDay.id == UUID() ? "Nouvelle journée" : "Modifier la journée")
        .alert("Erreur", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") {
                    saveWorkDay()
                }
            }
        }
    }
    
    private var typePicker: some View {
        Picker("Type", selection: $type) {
            ForEach(WorkDayType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
    }
    
    private var datePicker: some View {
        DatePicker(
            "Date",
            selection: $date,
            displayedComponents: [.date]
        )
    }
    
    @ViewBuilder
    private var timeSelectionView: some View {
        Section("Horaires") {
            DatePicker(
                "Début",
                selection: $startTime,
                displayedComponents: [.hourAndMinute]
            )
            DatePicker(
                "Fin",
                selection: $endTime,
                displayedComponents: [.hourAndMinute]
            )
            HStack {
                Text("Pause")
                Spacer()
                TextField("Pause", value: $breakDuration, format: .number)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                Text("minutes")
            }
        }
    }
    
    private func saveWorkDay() {
        if !type.isWorkDay {
            workDay.date = date
            workDay.type = type
            try? modelContext.save()
            dismiss()
            return
        }
        
        // Définir l'heure sur la bonne date
        guard let startDate = combineDateTime(date: date, time: startTime),
              let endDate = combineDateTime(date: date, time: endTime) else {
            showError("Une erreur est survenue avec les dates")
            return
        }
        
        if startDate >= endDate {
            showError("L'heure de début doit être avant l'heure de fin")
            return
        }
        
        workDay.date = date
        workDay.type = type
        workDay.updateData(
            startTime: startDate,
            endTime: endDate,
            breakDuration: breakDuration * 60
        )
        
        try? modelContext.save()
        dismiss()
    }
    
    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
    
    private func combineDateTime(date: Date, time: Date) -> Date? {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: timeComponents.hour ?? 0,
                           minute: timeComponents.minute ?? 0,
                           second: 0,
                           of: date)
    }
}
