import SwiftUI
import Observation

@Observable
class FirstLaunchManager {
    var showFirstSyncInfo = false
    
    init() {
        guard let userDefaults = UserDefaults(suiteName: SharedConstants.appGroupID) else {
            print("Error: App Group UserDefaults suite could not be initialized in FirstLaunchManager.init(). Defaulting to standard UserDefaults for this session (read-only equivalent).")
            // Fallback or error handling: For safety, perhaps prevent modification if app group is unavailable.
            // For now, reading from standard will likely return false for these keys if not set,
            // which might be acceptable for a first launch scenario if app group is broken.
            let hasCompletedFirstSync = UserDefaults.standard.bool(forKey: "hasCompletedFirstSync")
            let isReinstallation = UserDefaults.standard.bool(forKey: "isReinstallation")
            if !hasCompletedFirstSync || isReinstallation {
                showFirstSyncInfo = true
                // Not setting hasInitializedCloudKit here as we don't have app group defaults.
            }
            return
        }

        // Vérifier si c'est une première installation ou réinstallation
        let hasCompletedFirstSync = userDefaults.bool(forKey: "hasCompletedFirstSync")
        let isReinstallation = userDefaults.bool(forKey: "isReinstallation")
        
        if !hasCompletedFirstSync || isReinstallation {
            showFirstSyncInfo = true
            
            // Réinitialiser le statut CloudKit à la première installation
            // pour s'assurer que l'application démarre avec un état propre
            if !hasCompletedFirstSync {
                userDefaults.set(false, forKey: "hasInitializedCloudKit")
            }
        }
    }
    
    func markFirstSyncCompleted() {
        guard let userDefaults = UserDefaults(suiteName: SharedConstants.appGroupID) else {
            print("Error: App Group UserDefaults suite could not be initialized in FirstLaunchManager.markFirstSyncCompleted(). Changes will not be saved.")
            return
        }
        userDefaults.set(true, forKey: "hasCompletedFirstSync")
        userDefaults.set(false, forKey: "isReinstallation")
        showFirstSyncInfo = false
    }
}

struct FirstLaunchInfoView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Bienvenue dans WorkTimer")
                    .font(.title)
                    .bold()
                
                Text("Vos données seront automatiquement synchronisées entre vos appareils via iCloud.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Cette synchronisation est sécurisée et privée. Vos données restent chiffrées et ne sont accessibles qu'à vous.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Commencer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(trailing: Button("Fermer") {
                isPresented = false
            })
        }
    }
}

#Preview {
    FirstLaunchInfoView(isPresented: .constant(true))
} 
