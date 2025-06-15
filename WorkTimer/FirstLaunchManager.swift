import SwiftUI
import Observation

@Observable
class FirstLaunchManager {
    var showFirstSyncInfo = false
    
    init() {
        // Vérifier si c'est une première installation ou réinstallation
        let hasCompletedFirstSync = UserDefaults.standard.bool(forKey: "hasCompletedFirstSync")
        let isReinstallation = UserDefaults.standard.bool(forKey: "isReinstallation")
        
        if !hasCompletedFirstSync || isReinstallation {
            showFirstSyncInfo = true
            
            // Réinitialiser le statut CloudKit à la première installation
            // pour s'assurer que l'application démarre avec un état propre
            if !hasCompletedFirstSync {
                UserDefaults.standard.set(false, forKey: "hasInitializedCloudKit")
            }
        }
    }
    
    func markFirstSyncCompleted() {
        UserDefaults.standard.set(true, forKey: "hasCompletedFirstSync")
        UserDefaults.standard.set(false, forKey: "isReinstallation")
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
