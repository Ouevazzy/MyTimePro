// ModernCloudStatusView.swift
// Interface utilisateur pour afficher le statut de synchronisation avec les API modernes

import SwiftUI
import CloudKit
import Combine

struct ModernCloudStatusView: View {
    // Observer le service de synchronisation
    private var cloudService = ModernCloudService.shared
    
    // État local de l'interface
    @State private var showDetails = false
    
    var body: some View {
        VStack(spacing: 12) {
            // En-tête avec état
            HStack {
                Image(systemName: cloudService.syncStatus.iconName)
                    .font(.title3)
                    .foregroundColor(cloudService.syncStatus.color)
                    .symbolEffect(.pulse, 
                                 options: .repeating, 
                                 isActive: cloudService.syncStatus == .syncing(progress: 0.0))
                
                Text("iCloud")
                    .font(.headline)
                
                Spacer()
                
                Text(cloudService.syncStatus.description)
                    .font(.subheadline)
                    .foregroundColor(cloudService.syncStatus.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(cloudService.syncStatus.color.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            // Barre de progression (si en synchronisation)
            if case .syncing(let progress) = cloudService.syncStatus {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(cloudService.syncStatus.color)
                    .animation(.easeInOut, value: progress)
            }
            
            // Message utilisateur
            if let message = cloudService.userMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut, value: message)
            }
            
            // Dernière synchronisation
            if let lastSync = cloudService.lastSyncDate {
                HStack {
                    Text("Dernière synchronisation:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(timeAgo(lastSync))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Boutons d'action
            HStack(spacing: 20) {
                SyncButton(
                    title: "Synchroniser",
                    icon: "arrow.triangle.2.circlepath",
                    isLoading: cloudService.syncStatus == .syncing(progress: 0.0)
                ) {
                    syncAction()
                }
                
                SyncButton(
                    title: "Détails",
                    icon: "info.circle",
                    secondary: true
                ) {
                    showDetails.toggle()
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .sheet(isPresented: $showDetails) {
            CloudStatusDetailsView()
        }
    }
    
    // Formater le temps écoulé depuis la dernière synchronisation
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func syncAction() {
        Task {
            try? await cloudService.sendChanges()
        }
    }
}

// Bouton de synchronisation avec état de chargement
struct SyncButton: View {
    let title: String
    let icon: String
    var isLoading: Bool = false
    var secondary: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: secondary ? .blue : .white))
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: icon)
                        .font(.subheadline)
                        .symbolEffect(.pulse, 
                                     options: .repeating, 
                                     isActive: isLoading)
                }
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .foregroundColor(secondary ? .blue : .white)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(secondary ? Color.blue.opacity(0.1) : Color.blue)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }
}

// Vue détaillée pour la synchronisation
struct CloudStatusDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    private var cloudService = ModernCloudService.shared
    
    var body: some View {
        NavigationStack {
            List {
                // Section Statut
                Section("Statut") {
                    HStack {
                        Label("État actuel", systemImage: "info.circle")
                        Spacer()
                        Text(cloudService.syncStatus.description)
                            .foregroundColor(cloudService.syncStatus.color)
                    }
                    
                    if let lastSync = cloudService.lastSyncDate {
                        HStack {
                            Label("Dernière synchronisation", systemImage: "clock")
                            Spacer()
                            Text(formatDate(lastSync))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Section Actions
                Section("Actions") {
                    Button {
                        syncAction()
                        dismiss()
                    } label: {
                        Label("Synchroniser maintenant", systemImage: "arrow.triangle.2.circlepath")
                    }
                    
                    Button {
                        // Cette fonctionnalité est automatiquement gérée par SwiftData,
                        // mais nous gardons ce bouton pour rassurer l'utilisateur
                        showSimulatedRestoreAlert()
                    } label: {
                        Label("Restaurer les données", systemImage: "arrow.clockwise")
                    }
                }
                
                // Section Avancé pour le dépannage
                Section("Avancé") {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("Réinitialiser la synchronisation", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                            .foregroundColor(.red)
                    }
                    .confirmationDialog(
                        "Réinitialiser la synchronisation",
                        isPresented: $showResetConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Réinitialiser", role: .destructive) {
                            resetCloudKitAction()
                            dismiss()
                        }
                        Button("Annuler", role: .cancel) { }
                    } message: {
                        Text("Cette action va réinitialiser entièrement la synchronisation CloudKit. À utiliser uniquement en cas de problème persistant.\n\nL'application devra être redémarrée.")
                    }
                }
                
                // Section Informations
                Section("Informations") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("À propos de la synchronisation")
                            .font(.headline)
                        
                        Text("Vos données sont automatiquement synchronisées avec iCloud. Si vous supprimez et réinstallez l'application, vos données seront automatiquement restaurées depuis iCloud.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Synchronisation iCloud")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .alert("Restauration des données", isPresented: $showingRestoreAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Vos données sont automatiquement restaurées depuis iCloud. Aucune action manuelle n'est nécessaire.")
            }
        }
    }
    
    @State private var showingRestoreAlert = false
    @State private var showResetConfirmation = false
    
    private func showSimulatedRestoreAlert() {
        showingRestoreAlert = true
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func syncAction() {
        Task {
            try? await cloudService.sendChanges()
        }
    }
    
    private func resetCloudKitAction() {
        cloudService.resetCloudKitInitialization()
    }
}

// Vue d'information pour la première exécution ou réinstallation
struct FirstSyncInfoView: View {
    @Binding var isPresented: Bool
    private var cloudService = ModernCloudService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // En-tête
            Image(systemName: "arrow.clockwise.icloud")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .symbolEffect(.bounce, options: .repeating)
            
            Text("Synchronisation automatique")
                .font(.title)
                .fontWeight(.bold)
            
            // Contenu
            VStack(alignment: .leading, spacing: 16) {
                InfoRow(
                    icon: "icloud.fill",
                    title: "Vos données sur tous vos appareils",
                    text: "WorkTimer synchronise automatiquement vos données avec iCloud."
                )
                
                InfoRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Restauration automatique",
                    text: "Si vous supprimez et réinstallez l'application, vos données seront automatiquement restaurées."
                )
                
                InfoRow(
                    icon: "lock.fill",
                    title: "Sécurité",
                    text: "Vos données sont chiffrées et stockées en toute sécurité dans votre compte iCloud personnel."
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Statut actuel
            HStack {
                Image(systemName: cloudService.syncStatus.iconName)
                    .foregroundColor(cloudService.syncStatus.color)
                
                Text(cloudService.syncStatus.description)
                    .foregroundColor(cloudService.syncStatus.color)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(cloudService.syncStatus.color.opacity(0.1))
            .cornerRadius(12)
            
            // Bouton de fermeture
            Button {
                isPresented = false
            } label: {
                Text("Continuer")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top)
        }
        .padding()
        .onAppear {
            // Demander une synchronisation dès l'affichage
            cloudService.requestSync()
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview
struct ModernCloudStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ModernCloudStatusView()
                .padding()
            
            FirstSyncInfoView(isPresented: .constant(true))
                .frame(maxHeight: 550)
        }
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
