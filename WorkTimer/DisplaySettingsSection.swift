import SwiftUI

struct DisplaySettingsSection: View {
    @Bindable var settings: UserSettings
    @Binding var activeSection: SettingsSection?

    var body: some View {
        SettingsCard(
            title: "settings.display.title".localized, icon: "display", color: .purple,
            isExpanded: activeSection == .display,
            onToggle: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    activeSection = activeSection == .display ? nil : .display
                }
            }
        ) {
            VStack(spacing: DS.Spacing.lg) {
                Toggle("Format décimal", isOn: $settings.useDecimalHours).tint(.blue)
                FormatPreviewView(useDecimalHours: settings.useDecimalHours)
            }
            .padding(.vertical, 5).padding(.horizontal)
        }
    }
}

// MARK: - FormatPreviewView

struct FormatPreviewView: View {
    let useDecimalHours: Bool
    private let examples = [(hours: 7.5, minutes: 30), (hours: 8.0, minutes: 0), (hours: 9.75, minutes: 45)]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(examples, id: \.hours) { example in
                HStack {
                    Text("Exemple:").foregroundColor(.secondary)
                    Spacer()
                    if useDecimalHours {
                        Text(String(format: "%.2f", example.hours) + "h").fontWeight(.medium)
                    } else {
                        Text("\(Int(example.hours))h\(String(format: "%02d", example.minutes))").fontWeight(.medium)
                    }
                }
                .padding(.vertical, 5)
            }
        }
    }
}

// MARK: - ImprovedWeeklyHoursPickerView

struct ImprovedWeeklyHoursPickerView: View {
    @Binding var hours: Double
    @Binding var isPresented: Bool
    let onSave: (Double) -> Void

    @State private var animateSlider = false
    @State private var selectedPreset: Double?

    let presets: [(label: String, value: Double)] = [
        ("35h", 35.0), ("37.5h", 37.5), ("39h", 39.0), ("40h", 40.0), ("42h", 42.0)
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Heures hebdomadaires").font(.largeTitle).fontWeight(.bold)
            Text(String(format: "%.1f", hours) + "h")
                .font(.system(size: 60, weight: .bold, design: .rounded)).foregroundColor(.blue)
                .padding(.top, 20)
            sliderSection
            presetsSection
            adjustSection
            Spacer()
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Annuler") { isPresented = false }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Enregistrer") { onSave(hours); isPresented = false }
                    .fontWeight(.semibold)
            }
        }
    }

    private var sliderSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("1h").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("80h").font(.caption).foregroundColor(.secondary)
            }
            Slider(value: $hours, in: 1...80, step: 0.5)
                .tint(.blue)
                .accessibilityLabel("Heures hebdomadaires")
                .accessibilityValue("\(String(format: "%.1f", hours)) heures")
                .scaleEffect(x: animateSlider ? 1.0 : 0.9, y: 1.0)
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
                        animateSlider = true
                    }
                }
        }
        .padding(.vertical, 20)
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Préréglages communs").font(.headline)
            HStack {
                ForEach(presets, id: \.value) { preset in
                    Button(action: { withAnimation { hours = preset.value; selectedPreset = preset.value } }) {
                        Text(preset.label).padding(.vertical, 8).padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 20)
                                .fill(selectedPreset == preset.value ? Color.blue : Color(.systemGray5)))
                            .foregroundColor(selectedPreset == preset.value ? .white : .primary)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }

    private var adjustSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Ajustement précis").font(.headline)
            HStack {
                Button(action: { if hours > 0 { hours -= 0.5 } }) {
                    Image(systemName: "minus.circle.fill").font(.title).foregroundColor(.red)
                }
                Spacer()
                Button(action: { hours = 40.0 }) {
                    Text("Standard 40h").padding(.vertical, 8).padding(.horizontal, 15)
                        .background(RoundedRectangle(cornerRadius: 20).stroke(Color.blue, lineWidth: 1))
                        .foregroundColor(.blue)
                }
                Spacer()
                Button(action: { if hours < 80 { hours += 0.5 } }) {
                    Image(systemName: "plus.circle.fill").font(.title).foregroundColor(.green)
                }
            }
        }
    }
}

#Preview {
    DisplaySettingsSection(settings: UserSettings.shared, activeSection: .constant(.display))
        .padding()
}
