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
                    .foregroundStyle(cloudService.syncStatus.color)
                    .symbolEffect(.pulse,
                                 options: .repeating,
                                 isActive: isSyncing)
                
                Text("cloud.icloud.label".localized)
                    .font(.headline)
                
                Spacer()
                
                Text(cloudService.syncStatus.description)
                    .font(.subheadline)
                    .foregroundStyle(cloudService.syncStatus.color)
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
                    .animation(DS.Animation.progress, value: progress)
            }
            
            // Message utilisateur
            if let message = cloudService.userMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(DS.Animation.micro, value: message)
            }
            
            // Dernière synchronisation
            if let lastSync = cloudService.lastSyncDate {
                HStack {
                    Text("cloud.lastSync.label".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(timeAgo(lastSync))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Boutons d'action
            HStack(spacing: 20) {
                SyncButton(
                    title: "cloud.sync.button".localized,
                    icon: "arrow.triangle.2.circlepath",
                    isLoading: isSyncing
                ) {
                    syncAction()
                }

                SyncButton(
                    title: "cloud.details.button".localized,
                    icon: "info.circle",
                    secondary: true
                ) {
                    showDetails.toggle()
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .dsContentSurface(cornerRadius: DS.Radius.card)
        .sheet(isPresented: $showDetails) {
            CloudStatusDetailsView()
        }
    }
    
    // Check if currently syncing
    private var isSyncing: Bool {
        if case .syncing = cloudService.syncStatus {
            return true
        }
        return false
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
    
    @ViewBuilder
    var body: some View {
        if secondary {
            button
                .buttonStyle(.glass)
        } else {
            button
                .buttonStyle(.glassProminent)
        }
    }

    private var button: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
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
        }
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
                Section("cloud.section.status".localized) {
                    HStack {
                        Label("État actuel", systemImage: "info.circle")
                        Spacer()
                        Text(cloudService.syncStatus.description)
                            .foregroundStyle(cloudService.syncStatus.color)
                    }

                    if let lastSync = cloudService.lastSyncDate {
                        HStack {
                            Label("Dernière synchronisation", systemImage: "clock")
                            Spacer()
                            Text(formatDate(lastSync))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Section Actions
                Section("cloud.section.actions".localized) {
                    Button {
                        syncAction()
                        dismiss()
                    } label: {
                        Label("cloud.syncNow".localized, systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button {
                        // Cette fonctionnalité est automatiquement gérée par SwiftData,
                        // mais nous gardons ce bouton pour rassurer l'utilisateur
                        showSimulatedRestoreAlert()
                    } label: {
                        Label("cloud.restore".localized, systemImage: "arrow.clockwise")
                    }
                }
                
                // Section Avancé pour le dépannage
                Section("cloud.section.advanced".localized) {
                    Button(role: .destructive) {
                        showResetConfirmation = true
                    } label: {
                        Label("cloud.reset".localized, systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                            .foregroundStyle(.red)
                    }
                    .confirmationDialog(
                        "cloud.reset.title".localized,
                        isPresented: $showResetConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("cloud.reset.confirm".localized, role: .destructive) {
                            resetCloudKitAction()
                            dismiss()
                        }
                        Button("action.cancel".localized, role: .cancel) { }
                    } message: {
                        Text("cloud.reset.message".localized)
                    }
                }
                
                // Section Informations
                Section("cloud.section.about".localized) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("cloud.about.title".localized)
                            .font(.headline)

                        Text("cloud.about.description".localized)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("cloud.icloud.title".localized)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("action.close".localized) {
                        dismiss()
                    }
                }
            }
            .alert("cloud.restore.alert.title".localized, isPresented: $showingRestoreAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("cloud.restore.alert.message".localized)
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
    var cloudService = ModernCloudService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: 20) {
            // En-tête
            Image(systemName: "arrow.clockwise.icloud")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .symbolEffect(.bounce, value: animateIcon)
            
            Text("cloud.firstSync.title".localized)
                .font(.title)
                .fontWeight(.bold)

            // Contenu
            VStack(alignment: .leading, spacing: 16) {
                InfoRow(
                    icon: "icloud.fill",
                    title: "cloud.firstSync.devices".localized,
                    text: "cloud.firstSync.devicesDesc".localized
                )

                InfoRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "cloud.firstSync.restore".localized,
                    text: "cloud.firstSync.restoreDesc".localized
                )

                InfoRow(
                    icon: "lock.fill",
                    title: "cloud.firstSync.security".localized,
                    text: "cloud.firstSync.securityDesc".localized
                )
            }
            .padding()
            .dsContentSurface(cornerRadius: DS.Radius.medium)

            // Statut actuel
            HStack {
                Image(systemName: cloudService.syncStatus.iconName)
                    .foregroundStyle(cloudService.syncStatus.color)

                Text(cloudService.syncStatus.description)
                    .foregroundStyle(cloudService.syncStatus.color)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .dsContentSurface(cornerRadius: DS.Radius.medium)

            // Bouton de fermeture
            Button {
                isPresented = false
            } label: {
                Text("action.continue".localized)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.glassProminent)
            .padding(.top)
        }
        .padding()
        .onAppear {
            // Demander une synchronisation dès l'affichage
            animateIcon = !reduceMotion
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
                .foregroundStyle(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
