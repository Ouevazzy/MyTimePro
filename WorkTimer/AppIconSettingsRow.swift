import SwiftUI
import UIKit

private enum AppIcon: String, CaseIterable, Identifiable {
    case graphite
    case midnight
    case amber
    case smokedGlass
    case sapphire
    case frosted

    var id: String { rawValue }
    var title: String { "settings.appIcon.\(rawValue)".localized }
    var preview: String { "AppIconPreview-\(rawValue)" }

    var alternateName: String? {
        switch self {
        case .graphite: nil
        case .midnight: "AppIcon-Midnight"
        case .amber: "AppIcon-Amber"
        case .smokedGlass: "AppIcon-SmokedGlass"
        case .sapphire: "AppIcon-Sapphire"
        case .frosted: "AppIcon-Frosted"
        }
    }

    @MainActor static var current: Self {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.alternateName == name } ?? .graphite
    }
}

struct AppIconSettingsRow: View {
    @State private var selected = AppIcon.current
    @State private var showPicker = false
    @State private var isChanging = false
    @State private var showError = false

    var body: some View {
        Button {
            selected = .current
            showPicker = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                iconPreview(selected, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("settings.appIcon.title".localized)
                    Text(selected.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("settings.appIcon.title".localized)
        .accessibilityValue(selected.title)
        .accessibilityIdentifier("settings.appIcon.open")
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                List {
                    ForEach(AppIcon.allCases) { icon in
                        Button {
                            Task { await select(icon) }
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                iconPreview(icon, size: 54)
                                Text(icon.title)
                                Spacer()
                                if selected == icon {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color.accentColor)
                                        .accessibilityHidden(true)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected == icon ? .isSelected : [])
                        .accessibilityIdentifier("settings.appIcon.option.\(icon.id)")
                    }
                }
                .disabled(isChanging)
                .navigationTitle("settings.appIcon.title".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("action.done".localized) { showPicker = false }
                            .disabled(isChanging)
                    }
                }
                .alert("settings.appIcon.error".localized, isPresented: $showError) {
                    Button("action.done".localized, role: .cancel) {}
                }
            }
            .interactiveDismissDisabled(isChanging)
        }
    }

    private func iconPreview(_ icon: AppIcon, size: CGFloat) -> some View {
        Image(icon.preview)
            .resizable()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private func select(_ icon: AppIcon) async {
        guard !isChanging, icon != selected else { return }
        isChanging = true
        defer { isChanging = false }

        do {
            try await UIApplication.shared.setAlternateIconName(icon.alternateName)
            selected = .current
        } catch {
            AppLogger.error("Unable to change the app icon", category: AppLogger.ui, error: error)
            showError = true
        }
    }
}
