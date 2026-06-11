import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Bindable private var settings = UserSettings.shared

    // MARK: - State
    @State private var activeSection: SettingsSection? = nil
    @State private var showConfetti = false
    @State private var showPaywall = false
    @State private var showDiagnostics = false
    @State private var showOfferCodeRedemption = false
    @State private var subscriptionErrorMessage: String?
    @State private var showResetAlert = false
    @State private var animateWorkHours = false
    @State private var animateAnnualDays = false

    // Export
    @State private var exportType: ExportType?
    @State private var exportFormat: ExportFormat = .pdf
    @State private var exportYear = Calendar.current.component(.year, from: Date())
    @State private var exportMonth = Calendar.current.component(.month, from: Date())
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
                    subscriptionCard
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
            .dsScreenBackground(.gray)
        }
        .navigationTitle("navigation.settings".localized)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showDiagnostics) { DiagnosticsView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .offerCodeRedemption(isPresented: $showOfferCodeRedemption) { result in
            handleOfferCodeRedemption(result)
        }
        .sheet(item: $exportType) { type in
            PDFExportView(
                type: type,
                format: $exportFormat,
                selectedYear: $exportYear,
                selectedMonth: $exportMonth,
                userCompany: $userCompany
            )
        }
        .alert("settings.reset.confirm.title".localized, isPresented: $showResetAlert) {
            Button("action.cancel".localized, role: .cancel) { }
            Button("settings.reset.button".localized, role: .destructive) { resetAllData() }
        } message: {
            Text("settings.reset.confirm.message".localized)
        }
        .alert("paywall.error.title".localized, isPresented: Binding(
            get: { subscriptionErrorMessage != nil },
            set: { if !$0 { subscriptionErrorMessage = nil } }
        )) {
            Button("OK") { subscriptionErrorMessage = nil }
        } message: {
            Text(subscriptionErrorMessage ?? "")
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
                    TextField("settings.profile.name".localized, text: $userName)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                    TextField("settings.profile.company".localized, text: $userCompany)
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

    // MARK: - Subscription Card

    private var subscriptionCard: some View {
        SettingsCard(
            title: "settings.subscription.title".localized,
            icon: "star.fill",
            color: .orange,
            isExpanded: activeSection == .subscription,
            onToggle: {
                withAnimation(DS.Animation.cardToggle) {
                    activeSection = activeSection == .subscription ? nil : .subscription
                }
            }
        ) {
            VStack(spacing: DS.Spacing.sm) {
                // Status banner
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: StoreManager.shared.isPro ? "checkmark.seal.fill" : "lock.fill")
                        .font(.title2)
                        .foregroundStyle(StoreManager.shared.isPro ? .orange : .secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(StoreManager.shared.isPro
                             ? "WorkTimer Pro"
                             : "settings.subscription.free".localized)
                            .font(.headline)
                        Text(subscriptionPlanName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if StoreManager.shared.isPro {
                        Text("PRO")
                            .font(.caption2).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.orange, in: Capsule())
                    }
                }
                .padding(DS.Spacing.md)
                .background(
                    StoreManager.shared.isPro
                        ? Color.orange.opacity(0.1)
                        : Color(.tertiarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: DS.Radius.medium)
                )

                if StoreManager.shared.isPro {
                    if StoreManager.shared.activeProductID == StoreManager.lifetimeID {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.orange)
                            Text("settings.subscription.lifetimeActive".localized)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(DS.Spacing.md)
                        .background(Color(.tertiarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                    } else {
                        // Manage subscription
                        Button(action: openSubscriptionManagement) {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: "creditcard.fill")
                                    .foregroundStyle(.orange)
                                Text("settings.subscription.manage".localized)
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(DS.Spacing.md)
                            .background(Color(.tertiarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                        }
                        .foregroundStyle(.primary)
                        .buttonStyle(.pressable)

                        redeemCodeButton
                    }
                } else {
                    // Upgrade button
                    Button(action: { showPaywall = true }) {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                            Text("settings.subscription.upgrade".localized)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding()
                        .background(
                            LinearGradient(colors: [.orange, .yellow],
                                           startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: DS.Radius.medium)
                        )
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.pressable)

                    redeemCodeButton

                    // Restore purchases
                    Button(action: {
                        Task {
                            await StoreManager.shared.restorePurchases()
                        }
                    }) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundStyle(.blue)
                            Text("paywall.restore".localized)
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(DS.Spacing.md)
                        .background(Color(.tertiarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                    }
                    .foregroundStyle(.primary)
                    .buttonStyle(.pressable)
                }

                // Legal links — always visible (Apple requirement)
                HStack(spacing: DS.Spacing.sm) {
                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.blue)
                            Text("settings.subscription.terms".localized)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.md)
                        .background(Color(.tertiarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                    }
                    .foregroundStyle(.primary)

                    Link(destination: URL(string: "https://ouevazzy.github.io/MyTimePro-Support/")!) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(.green)
                            Text("settings.subscription.privacy".localized)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.md)
                        .background(Color(.tertiarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                    }
                    .foregroundStyle(.primary)
                }
            }
            .padding()
        }
    }

    private var redeemCodeButton: some View {
        Button {
            showOfferCodeRedemption = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "ticket.fill")
                    .foregroundStyle(.orange)
                Text("paywall.redeemCode.title".localized)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(DS.Spacing.md)
            .background(Color(.tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: DS.Radius.medium))
        }
        .foregroundStyle(.primary)
        .buttonStyle(.pressable)
    }

    private var subscriptionPlanName: String {
        guard StoreManager.shared.isPro, let id = StoreManager.shared.activeProductID else {
            return "settings.subscription.free".localized
        }
        switch id {
        case StoreManager.monthlyID:  return "paywall.plan.monthly".localized
        case StoreManager.annualID:   return "paywall.plan.annual".localized
        case StoreManager.lifetimeID: return "paywall.plan.lifetime".localized
        default: return "Pro"
        }
    }

    private func openSubscriptionManagement() {
        guard let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") else { return }
        openURL(url)
    }

    private func handleOfferCodeRedemption(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            Task { @MainActor in
                await StoreManager.shared.refreshAfterExternalRedemption()
                guard StoreManager.shared.isPro else { return }

                withAnimation(DS.Animation.appear) {
                    showConfetti = true
                }
                try? await Task.sleep(for: .seconds(2))
                withAnimation(DS.Animation.appear) {
                    showConfetti = false
                }
            }
        case .failure(let error):
            AppLogger.error("StoreKit: rachat de code échoué", category: AppLogger.data, error: error)
            subscriptionErrorMessage = "paywall.error.redeemCode".localized
        }
    }

    // MARK: - About Card

    private var aboutCard: some View {
        SettingsCard(
            title: "settings.about.title".localized, icon: "info.circle.fill", color: .blue,
            isExpanded: activeSection == .about,
            onToggle: {
                withAnimation(DS.Animation.cardToggle) {
                    activeSection = activeSection == .about ? nil : .about
                }
            }
        ) {
            VStack(spacing: DS.Spacing.sm) {
                HStack {
                    Text("settings.version.label".localized)
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

                Button(action: openPrivacyPolicy) {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.green)
                        Text("settings.privacyPolicy".localized)
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "arrow.up.right")
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
            title: "settings.reset".localized, icon: "arrow.counterclockwise", color: .red,
            isExpanded: activeSection == .reset,
            onToggle: {
                withAnimation(DS.Animation.cardToggle) {
                    activeSection = activeSection == .reset ? nil : .reset
                }
            }
        ) {
            VStack(spacing: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.lg) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle).foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("settings.reset.warning".localized).font(.headline).foregroundStyle(.orange)
                        Text("settings.reset.warning.message".localized).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.medium))

                Button(role: .destructive) { showResetAlert = true } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("settings.reset.button".localized).fontWeight(.semibold)
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                    .foregroundStyle(.red)
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func resetAllData() {
        do {
            let all = try modelContext.fetch(FetchDescriptor<WorkDay>())
            for workDay in all { modelContext.delete(workDay) }
            try modelContext.save()
            settings.resetToDefaults()
            SiriSummaryCacheService().refresh(using: modelContext)
        } catch {
            ErrorManager.shared.handleDataError("Erreur suppression: \(error.localizedDescription)")
        }
    }

    private func openPrivacyPolicy() {
        guard let url = URL(string: "https://ouevazzy.github.io/MyTimePro-Support/") else { return }
        openURL(url)
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
