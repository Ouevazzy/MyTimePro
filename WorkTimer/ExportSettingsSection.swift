import SwiftUI

struct ExportSettingsSection: View {
    @Binding var activeSection: SettingsSection?
    @Binding var exportType: ExportType?
    @Binding var exportFormat: ExportFormat
    @Binding var userCompany: String

    var body: some View {
        SettingsCard(
            title: "settings.export.title".localized, icon: "square.and.arrow.up", color: .green,
            isExpanded: activeSection == .export,
            onToggle: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
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
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Format d'export").font(.headline)
            Picker("Format", selection: $exportFormat) {
                Text("PDF").tag(ExportFormat.pdf)
                Text("CSV").tag(ExportFormat.csv)
            }
            .pickerStyle(.segmented).padding(.vertical, 5)
        }
    }

    private var exportButtons: some View {
        HStack(spacing: 15) {
            ExportOptionButton(
                icon: "calendar.badge.clock", title: "Export mensuel",
                subtitle: "Données détaillées du mois",
                action: { exportType = .monthly }
            )
            ExportOptionButton(
                icon: "doc.text.fill", title: "Export annuel",
                subtitle: "Résumé complet avec graphiques",
                action: { exportType = .annual }
            )
        }
    }

    private var customizationRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Personnalisation").font(.headline)
            HStack {
                Text("Nom de l'entreprise:").foregroundColor(.secondary)
                TextField("Nom à afficher", text: $userCompany).textFieldStyle(RoundedBorderTextFieldStyle())
            }
            Text("Ce nom sera affiché sur les documents exportés")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding().background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
    }
}

// MARK: - ExportOptionButton

private struct ExportOptionButton: View {
    let icon: String; let title: String; let subtitle: String; let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 24)).foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(RoundedRectangle(cornerRadius: 15).fill(Color.green))
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            .padding().frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
        }
        .foregroundColor(.primary)
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
