import Foundation
import Combine
import CloudKit

class TimeRecordingViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var startTime = Date()
    @Published var endTime = Date()
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    var duration: String? {
        let difference = endTime.timeIntervalSince(startTime)
        guard difference > 0 else { return nil }
        
        let hours = Int(difference / 3600)
        let minutes = Int((difference.truncatingRemainder(dividingBy: 3600)) / 60)
        
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    var canSave: Bool {
        guard let _ = duration else { return false }
        return endTime > startTime
    }
    
    func saveTime() {
        Task {
            do {
                let timeRecord = TimeRecord(
                    date: selectedDate,
                    startTime: startTime,
                    endTime: endTime
                )
                try await CloudKitManager.shared.saveTimeRecord(timeRecord)
                
                await MainActor.run {
                    alertMessage = "Temps enregistré avec succès"
                    showingAlert = true
                    resetForm()
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Erreur: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func resetForm() {
        selectedDate = Date()
        startTime = Date()
        endTime = Date()
    }
}
