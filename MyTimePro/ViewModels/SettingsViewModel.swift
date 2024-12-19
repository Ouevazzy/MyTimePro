import Foundation
import Combine
import CloudKit

class SettingsViewModel: ObservableObject {
    @Published var iCloudStatus: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .settingsDidChange)
            .sink { [weak self] notification in
                if let settings = notification.object as? Settings {
                    self?.updateSettings(settings)
                }
            }
            .store(in: &cancellables)
    }
    
    func checkICloudStatus() {
        Task {
            do {
                let status = try await CloudKitManager.shared.checkAccountStatus()
                await MainActor.run {
                    self.iCloudStatus = self.statusString(for: status)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.iCloudStatus = "Erreur"
                }
            }
        }
    }
    
    func syncSettings() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let settings = Settings(
                    weeklyHours: UserDefaults.standard.double(forKey: "weeklyHours"),
                    dailyHours: UserDefaults.standard.double(forKey: "dailyHours"),
                    vacationDays: UserDefaults.standard.double(forKey: "vacationDays"),
                    workingDays: Set(UserDefaults.standard.array(forKey: "workingDays") as? [Int] ?? Array(1...5))
                )
                try await CloudKitManager.shared.saveSettings(settings)
                
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func updateSettings(_ settings: Settings) {
        UserDefaults.standard.set(settings.weeklyHours, forKey: "weeklyHours")
        UserDefaults.standard.set(settings.dailyHours, forKey: "dailyHours")
        UserDefaults.standard.set(settings.vacationDays, forKey: "vacationDays")
        UserDefaults.standard.set(Array(settings.workingDays), forKey: "workingDays")
    }
    
    private func statusString(for status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "Disponible"
        case .noAccount:
            return "Pas de compte"
        case .restricted:
            return "Restreint"
        case .couldNotDetermine:
            return "Indéterminé"
        @unknown default:
            return "Inconnu"
        }
    }
}
