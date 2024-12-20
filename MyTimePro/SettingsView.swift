import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var cloudService = CloudService.shared
    @State private var showingSyncError = false
    @State private var errorMessage = ""
    @State private var showingBackupSuccess = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("iCloud")) {
                    HStack {
                        Text("Statut iCloud")
                        Spacer()
                        if cloudService.isCloudAvailable {
                            Text("Connecté")
                                .foregroundColor(.green)
                        } else {
                            Text("Déconnecté")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await syncData()
                        }
                    }) {
                        Text("Synchroniser maintenant")
                    }
                }
                
                Section(header: Text("Exportation")) {
                    NavigationLink {
                        PDFExportView()
                    } label: {
                        Label("Exporter en PDF", systemImage: "doc.fill")
                    }
                }
            }
            .navigationTitle("Paramètres")
        }
        .alert("Erreur de synchronisation", isPresented: $showingSyncError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Synchronisation réussie", isPresented: $showingBackupSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Vos données ont été synchronisées avec iCloud")
        }
    }
    
    private func syncData() async {
        do {
            try await cloudService.syncWithCloud(context: modelContext)
            await MainActor.run {
                showingBackupSuccess = true
            }
        } catch {
            await MainActor.run {
                showingSyncError = true
                errorMessage = error.localizedDescription
            }
        }
    }
}
