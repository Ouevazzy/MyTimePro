import SwiftUI

struct PrivacySettingsSection: View {
    @Binding var activeSection: SettingsSection?
    var cloudService = ModernCloudService.shared
    @State private var showRestoreAlert = false

    var body: some View {
        SettingsCard(
            title: "settings.privacy.title".localized, icon: "lock.shield.fill", color: .cyan,
            isExpanded: activeSection == .privacy,
            onToggle: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    activeSection = activeSection == .privacy ? nil : .privacy
                }
            }
        ) {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                introText
                guaranteesSection
                Divider()
                iCloudSection
                dataControlSection
            }
            .padding()
        }
        .alert("sync.restore.title".localized, isPresented: $showRestoreAlert) {
            Button("action.cancel".localized, role: .cancel) { }
            Button("sync.restore.action".localized, role: .destructive) {
                Task { await cloudService.restoreFromCloud() }
            }
        } message: {
            Text("sync.restore.message".localized)
        }
    }

    private var introText: some View {
        Text("settings.privacy.message".localized)
            .font(.subheadline).foregroundColor(.secondary).padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.cyan.opacity(0.1)))
    }

    private var guaranteesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            PrivacyFeatureRow(icon: "checkmark.shield.fill", text: "privacy.encryption".localized, color: .green)
            PrivacyFeatureRow(icon: "checkmark.shield.fill", text: "privacy.noThirdParty".localized, color: .green)
            PrivacyFeatureRow(icon: "checkmark.shield.fill", text: "privacy.localFirst".localized, color: .green)
            PrivacyFeatureRow(icon: "checkmark.shield.fill", text: "privacy.noTracking".localized, color: .green)
            PrivacyFeatureRow(icon: "checkmark.shield.fill", text: "privacy.dataOwnership".localized, color: .green)
        }
    }

    private var iCloudSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "icloud.fill").foregroundColor(.blue)
                Text("settings.privacy.icloud".localized).font(.headline)
            }
            Text("settings.privacy.icloud.message".localized)
                .font(.caption).foregroundColor(.secondary)
            if cloudService.syncStatus != .idle {
                HStack {
                    Image(systemName: cloudService.syncStatus.iconName).foregroundColor(cloudService.syncStatus.color)
                    Text(cloudService.syncStatus.description).font(.caption).foregroundColor(.secondary)
                }
                .padding(.top, 5)
            }
        }
        .padding().background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }

    private var dataControlSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "gear").foregroundColor(.orange)
                Text("settings.privacy.dataControl".localized).font(.headline)
            }
            Text("settings.privacy.dataControl.message".localized)
                .font(.caption).foregroundColor(.secondary)
        }
        .padding().background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

#Preview {
    PrivacySettingsSection(activeSection: .constant(.privacy)).padding()
}
