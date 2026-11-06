import SwiftUI

struct ExportSettingsSection: View {
    private var store: StoreManager { StoreManager.shared }
    @Binding var activeSection: SettingsSection?
    @Binding var exportType: ExportType?
    @Binding var exportFormat: ExportFormat
    @Binding var userCompany: String
    @State private var showPaywall = false

    var body: some View {
        SettingsCard(
            title: "settings.export.title".localized, icon: "square.and.arrow.up", color: .green,
            isExpanded: activeSection == .export,
            onToggle: {
                withAnimation(DS.Animation.cardToggle) {
                    activeSection = activeSection == .export ? nil : .export
                }
            }
        ) {
            VStack(spacing: DS.Spacing.xl) {
                formatPicker
                exportButtons
                customizationRow
            }
            .padding()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("settings.export.format".localized).font(.headline)
            Picker("settings.export.format".localized, selection: $exportFormat) {
                Text("PDF").tag(ExportFormat.pdf)
                Text("CSV").tag(ExportFormat.csv)
            }
            .pickerStyle(.segmented)
            .padding(.vertical, DS.Spacing.xs)
        }
    }

    private var exportButtons: some View {
        HStack(spacing: DS.Spacing.lg) {
            ExportOptionButton(
                icon: "calendar.badge.clock",
                title: "settings.export.monthly".localized,
                subtitle: "settings.export.monthly.subtitle".localized,
                action: { if store.isPro { exportType = .monthly } else { showPaywall = true } }
            )
            ExportOptionButton(
                icon: "doc.text.fill",
                title: "settings.export.annual".localized,
                subtitle: "settings.export.annual.subtitle".localized,
                action: { if store.isPro { exportType = .annual } else { showPaywall = true } }
            )
        }
    }

    private var customizationRow: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("settings.export.customization".localized).font(.headline)
            HStack {
                Text("settings.export.companyName".localized).foregroundStyle(.secondary)
                TextField("export.company.placeholder".localized, text: $userCompany)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Text("settings.export.companyName.hint".localized)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: DS.Radius.medium))
    }
}

// MARK: - ExportOptionButton

private struct ExportOptionButton: View {
    let icon: String; let title: String; let subtitle: String; let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: DS.Radius.card))
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: DS.Radius.medium))
        }
        .foregroundStyle(.primary)
    }
}

#Preview {
    ExportSettingsSection(
        activeSection: .constant(.export),
        exportType: .constant(nil),
        exportFormat: .constant(.pdf),
        userCompany: .constant("Ma Société")
    )
    .padding()
}
