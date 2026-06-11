import SwiftUI
import StoreKit

struct PaywallView: View {
    private var store: StoreManager { StoreManager.shared }
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = StoreManager.annualID
    @State private var isPurchasing = false
    @State private var showOfferCodeRedemption = false
    @State private var showSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    header
                    featuresList
                    planPicker
                    purchaseButton
                    redeemCodeButton
                    restoreButton
                    legalLinks
                    legalNote
                }
                .padding()
                .padding(.bottom, DS.Spacing.xl)
            }
            .dsScreenBackground(.blue)
            .navigationTitle("WorkTimer Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("paywall.close".localized) { dismiss() }.fontWeight(.medium)
                }
            }
            .overlay(alignment: .top) {
                if showSuccess {
                    ConfettiView().allowsHitTesting(false).ignoresSafeArea()
                }
            }
            .alert("paywall.error.title".localized, isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .offerCodeRedemption(isPresented: $showOfferCodeRedemption) { result in
                handleOfferCodeRedemption(result)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(
                        colors: [.orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                Image(systemName: "star.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .shadow(color: .orange.opacity(0.3), radius: 12, y: 6)

            Text("paywall.headline".localized)
                .font(.title.bold())

            Text("paywall.subtitle".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DS.Spacing.md)
    }

    // MARK: - Features list

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            PaywallFeatureRow(icon: "doc.fill", color: .green,
                              title: "paywall.feature.export.title".localized,
                              subtitle: "paywall.feature.export.subtitle".localized)
            PaywallFeatureRow(icon: "chart.bar.fill", color: .blue,
                              title: "paywall.feature.charts.title".localized,
                              subtitle: "paywall.feature.charts.subtitle".localized)
            PaywallFeatureRow(icon: "mic.fill", color: .purple,
                              title: "paywall.feature.siri.title".localized,
                              subtitle: "paywall.feature.siri.subtitle".localized)
        }
        .padding()
        .dsGlassSurface(cornerRadius: DS.Radius.card)
    }

    // MARK: - Plan picker

    private var planPicker: some View {
        VStack(spacing: DS.Spacing.sm) {
            if store.products.isEmpty {
                ProgressView("paywall.loading".localized)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(store.products, id: \.id) { product in
                    PlanCard(
                        product: product,
                        isSelected: selectedID == product.id,
                        badge: planBadge(for: product.id),
                        detail: planDetail(for: product)
                    ) {
                        withAnimation(DS.Animation.micro) { selectedID = product.id }
                    }
                }
            }
        }
    }

    // MARK: - Purchase button

    private var purchaseButton: some View {
        Button {
            Task { await performPurchase() }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(purchaseLabel).font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.glassProminent)
        .tint(.orange)
        .disabled(isPurchasing || store.products.isEmpty)
    }

    private var redeemCodeButton: some View {
        Button {
            showOfferCodeRedemption = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "ticket.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                    .frame(width: 32, height: 32)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: DS.IconRadius.inline))

                VStack(alignment: .leading, spacing: 2) {
                    Text("paywall.redeemCode.title".localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("paywall.redeemCode.subtitle".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DS.Radius.card))
        }
        .buttonStyle(.pressable)
        .foregroundStyle(.primary)
        .disabled(isPurchasing)
    }

    private var purchaseLabel: String {
        guard let product = store.products.first(where: { $0.id == selectedID }) else {
            return "paywall.purchase.choosePlan".localized
        }
        let format = product.id == StoreManager.lifetimeID
            ? "paywall.purchase.lifetime".localized
            : "paywall.purchase.subscribe".localized
        return String(format: format, product.displayPrice)
    }

    // MARK: - Footer

    private var restoreButton: some View {
        Button("paywall.restore".localized) {
            Task {
                await store.restorePurchases()
                if store.isPro { dismiss() }
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var legalLinks: some View {
        HStack(spacing: DS.Spacing.md) {
            Link("paywall.legal.privacy".localized,
                 destination: URL(string: "https://ouevazzy.github.io/MyTimePro-Support/")!)
            Text("·").foregroundStyle(.tertiary)
            Link("paywall.legal.terms".localized,
                 destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var legalNote: some View {
        Text(selectedID == StoreManager.lifetimeID
             ? "paywall.legal.lifetime".localized
             : "paywall.legal.subscription".localized)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }

    // MARK: - Helpers

    private func planBadge(for id: String) -> String? {
        switch id {
        case StoreManager.annualID:   return "paywall.plan.popular".localized
        case StoreManager.lifetimeID: return "paywall.plan.bestDeal".localized
        default: return nil
        }
    }

    private func planDetail(for product: Product) -> String? {
        guard product.id == StoreManager.annualID else { return nil }
        let monthly = product.price / 12
        return String(format: "paywall.plan.monthlyEquiv".localized,
                      monthly.formatted(product.priceFormatStyle))
    }

    private func performPurchase() async {
        guard let product = store.products.first(where: { $0.id == selectedID }) else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await store.purchase(product)
            if store.isPro {
                showSuccess = true
                try? await Task.sleep(for: .seconds(2))
                dismiss()
            }
        } catch {
            errorMessage = "paywall.error.purchase".localized
        }
    }

    private func handleOfferCodeRedemption(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            Task { @MainActor in
                await store.refreshAfterExternalRedemption()
                if store.isPro {
                    showSuccess = true
                    try? await Task.sleep(for: .seconds(2))
                    dismiss()
                }
            }
        case .failure(let error):
            AppLogger.error("StoreKit: rachat de code échoué", category: AppLogger.data, error: error)
            errorMessage = "paywall.error.redeemCode".localized
        }
    }
}

// MARK: - PlanCard

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let detail: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.orange : Color.secondary)
                    .animation(DS.Animation.micro, value: isSelected)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(planTitle)
                            .font(.subheadline).fontWeight(.semibold)
                        if let badge {
                            Text(badge)
                                .font(.caption2).fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(.orange, in: Capsule())
                        }
                    }
                    if let detail {
                        Text(detail)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.headline).fontWeight(.bold)
                    Text(periodLabel)
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .fill(Color(.secondarySystemGroupedBackground).opacity(isSelected ? 0.82 : 0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.card)
                            .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                    )
            )
            .dsGlassSurface(cornerRadius: DS.Radius.card, interactive: true)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var planTitle: String {
        switch product.id {
        case StoreManager.monthlyID:  return "paywall.plan.monthly".localized
        case StoreManager.annualID:   return "paywall.plan.annual".localized
        case StoreManager.lifetimeID: return "paywall.plan.lifetime".localized
        default: return product.displayName
        }
    }

    private var periodLabel: String {
        switch product.id {
        case StoreManager.monthlyID:  return "paywall.plan.perMonth".localized
        case StoreManager.annualID:   return "paywall.plan.perYear".localized
        case StoreManager.lifetimeID: return "paywall.plan.oneTime".localized
        default: return ""
        }
    }
}

// MARK: - PaywallFeatureRow

struct PaywallFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: RoundedRectangle(cornerRadius: DS.IconRadius.inline))

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark")
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(.green)
        }
    }
}

#Preview {
    PaywallView()
}
