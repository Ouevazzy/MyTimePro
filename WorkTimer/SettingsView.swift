import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Bindable private var settings = UserSettings.shared
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]

    // MARK: - State
    @State private var activeSection: SettingsSection? = nil
    @State private var showConfetti = false
    @State private var showDiagnostics = false
    @State private var showResetAlert = false
    @State private var animateWorkHours = false
    @State private var animateAnnualDays = false

    // Export
    @State private var exportType: ExportType?
    @State private var exportFormat: ExportFormat = .pdf
    @AppStorage("userProfile.name") private var userName = ""
    @AppStorage("userProfile.company") private var userCompany = ""

    // MARK: - Body
    var body: some View {
        ZStack {
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(999)
            }
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    profileHeader
                    WorkTimeSettingsSection(
                        settings: settings,
                        activeSection: $activeSection,
                        showConfetti: $showConfetti
                    )
                    DisplaySettingsSection(
                        settings: settings,
                        activeSection: $activeSection
                    )
                    FeaturesSettingsSection(activeSection: $activeSection)
                    PrivacySettingsSection(activeSection: $activeSection)
                    ExportSettingsSection(
                        activeSection: $activeSection,
                        exportType: $exportType,
                        exportFormat: $exportFormat,
                        userCompany: $userCompany
                    )
                    aboutCard
                    resetCard
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("Réglages")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showDiagnostics) { DiagnosticsView() }
        .sheet(item: $exportType) { type in
            PDFExportView(
                type: type,
                format: $exportFormat,
                selectedYear: .constant(Calendar.current.component(.year, from: Date())),
                selectedMonth: .constant(Calendar.current.component(.month, from: Date())),
                userCompany: $userCompany
            )
        }
        .alert("settings.reset.confirm.title".localized, isPresented: $showResetAlert) {
            Button("action.cancel".localized, role: .cancel) { }
            Button("settings.reset.button".localized, role: .destructive) { resetAllData() }
        } message: {
            Text("settings.reset.confirm.message".localized)
        }
        .onAppear {
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation(DS.Animation.appear) { animateWorkHours = true }
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(DS.Animation.appear) { animateAnnualDays = true }
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                RoundedRectangle(cornerRadius: DS.Radius.medium)
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(userName.isEmpty ? "?" : String(userName.prefix(1)).uppercased())
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    TextField("Votre nom", text: $userName)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                    TextField("Entreprise", text: $userCompany)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.Radius.card))

            HStack(spacing: DS.Spacing.md) {
                StatisticCard(
                    title: "settings.weeklyHours".localized,
                    value: String(format: "%.1fh", settings.weeklyHours),
                    icon: "clock.fill", color: .blue,
                    iconBackground: .blue.opacity(0.2),
                    animate: animateWorkHours
                )
                StatisticCard(
                    title: "settings.annualVacationDays".localized,
                    value: "\(settings.annualVacationDays) \("time.days".localized)",
                    icon: "sun.max.fill", color: .orange,
                    iconBackground: .orange.opacity(0.2),
                    animate: animateAnnualDays
                )
            }
        }
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - About Card

    private var aboutCard: some View {
        SettingsCard(
            title: "À propos", icon: "info.circle.fill", color: .blue,
            isExpanded: activeSection == .about,
            onToggle: {
                withAnimation(DS.Animation.cardToggle) {
                    activeSection = activeSection == .about ? nil : .about
                }
            }
        ) {
            VStack(spacing: DS.Spacing.sm) {
                HStack {
                    Text("Version")
                        .font(.subheadline)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(DS.Spacing.md)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.Radius.medium))

                Button(action: sendSupportEmail) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.blue)
                        Text("settings.support".localized)
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(DS.Spacing.md)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                }
                .foregroundStyle(.primary)
                .buttonStyle(.pressable)

                Button { showDiagnostics = true } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "stethoscope")
                            .foregroundStyle(.purple)
                        Text("settings.diagnostics".localized)
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(DS.Spacing.md)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                }
                .foregroundStyle(.primary)
                .buttonStyle(.pressable)
            }
            .padding()
        }
    }

    // MARK: - Reset Card

    private var resetCard: some View {
        SettingsCard(
            title: "Réinitialisation", icon: "arrow.counterclockwise", color: .red,
            isExpanded: activeSection == .reset,
            onToggle: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    activeSection = activeSection == .reset ? nil : .reset
                }
            }
        ) {
            VStack(spacing: 15) {
                HStack(spacing: 15) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle).foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("settings.reset.warning".localized).font(.headline).foregroundColor(.orange)
                        Text("settings.reset.warning.message".localized).font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))

                Button(role: .destructive) { showResetAlert = true } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Réinitialiser les paramètres").fontWeight(.semibold)
                        Spacer()
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.1)))
                    .foregroundColor(.red)
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func resetAllData() {
        for workDay in workDays { modelContext.delete(workDay) }
        do {
            try modelContext.save()
            settings.resetToDefaults()
        } catch {
            ErrorManager.shared.handleDataError("Erreur suppression: \(error.localizedDescription)")
        }
    }

    private func sendSupportEmail() {
        let version = Bundle.main.appVersionString
        let subject = "Support WorkTimer"
        let body = "Bonjour,\n\nDécrivez votre problème ici.\n\nVersion: \(version)\n"
        let enc = CharacterSet.urlQueryAllowed
        guard let url = URL(string: "mailto:timeflowpro@gmail.com?subject=\(subject.addingPercentEncoding(withAllowedCharacters: enc) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: enc) ?? "")") else { return }
        openURL(url)
    }
}

// MARK: - Preview

#Preview {
    SettingsView().modelContainer(for: WorkDay.self, inMemory: true)
}
