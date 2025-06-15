import SwiftUI

struct SyncDetailsView: View {
    @Environment(ModernCloudService.self) private var cloudService
    @State private var showingResetAlert = false
    
    var body: some View {
        List {
            Section {
                ModernCloudStatusView()
            }
            
            Section("Statut détaillé") {
                HStack {
                    Text("Dernière synchronisation")
                    Spacer()
                    if let lastSync = cloudService.lastSyncDate {
                        Text(lastSync.formatted(.relative(presentation: .named)))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Jamais")
                            .foregroundColor(.secondary)
                    }
                }
                
                if case .failed(let error) = cloudService.syncStatus {
                    HStack {
                        Text("Erreur")
                        Spacer()
                        Text(error.localizedDescription)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Section("Actions") {
                Button(action: {
                    Task {
                        try? await cloudService.sendChanges()
                    }
                }) {
                    Label("Synchroniser maintenant", systemImage: "arrow.triangle.2.circlepath")
                }
                
                Button(action: {
                    showingResetAlert = true
                }) {
                    Label("Réinitialiser la synchronisation", systemImage: "arrow.counterclockwise")
                        .foregroundColor(.red)
                }
            }
            
            Section("À propos") {
                Text("La synchronisation utilise iCloud pour garder vos données à jour sur tous vos appareils. Les données sont chiffrées et sécurisées.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Synchronisation")
        .alert("Réinitialiser la synchronisation", isPresented: $showingResetAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Réinitialiser", role: .destructive) {
                Task {
                    cloudService.initialize()
                }
            }
        } message: {
            Text("Cette action supprimera toutes les données de synchronisation et redémarrera le processus depuis le début. Vos données locales ne seront pas affectées.")
        }
    }
}

struct SyncDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SyncDetailsView()
                .environment(ModernCloudService.shared)
        }
    }
} 