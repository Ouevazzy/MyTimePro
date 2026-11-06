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
                Toggle("settings.display.decimalFormat".localized, isOn: $settings.useDecimalHours).tint(.blue)
                FormatPreviewView(useDecimalHours: settings.useDecimalHours)

                Divider()

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Toggle("settings.display.showTimer".localized, isOn: $settings.showLiveTimer).tint(.blue)
                    Text("settings.display.showTimer.help".localized)
                        .font(.caption).foregroundStyle(.secondary)
                }
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
                    Text("settings.display.example".localized).foregroundStyle(.secondary)
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
            Text("settings.display.weeklyHours".localized).font(.largeTitle).fontWeight(.bold)
            Text(String(format: "%.1f", hours) + "h")
                .font(.system(size: 60, weight: .bold, design: .rounded)).foregroundStyle(.blue)
                .padding(.top, 20)
            sliderSection
            presetsSection
            adjustSection
            Spacer()
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("action.cancel".localized) { isPresented = false }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("action.save".localized) { onSave(hours); isPresented = false }
                    .fontWeight(.semibold)
            }
        }
    }

    private var sliderSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("1h").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("80h").font(.caption).foregroundStyle(.secondary)
            }
            Slider(value: $hours, in: 1...80, step: 0.5)
                .tint(.blue)
                .accessibilityLabel("settings.display.weeklyHours".localized)
                .accessibilityValue("settings.display.hoursValue".localized(String(format: "%.1f", hours)))
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
            Text("settings.display.presets.common".localized).font(.headline)
            HStack {
                ForEach(presets, id: \.value) { preset in
                    Button(action: { withAnimation { hours = preset.value; selectedPreset = preset.value } }) {
                        Text(preset.label).padding(.vertical, 8).padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 20)
                                .fill(selectedPreset == preset.value ? Color.blue : Color(.systemGray5)))
                            .foregroundStyle(selectedPreset == preset.value ? .white : .primary)
                    }
                }
            }
            .padding(.vertical, 10)
        }
    }

    private var adjustSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("settings.display.adjustment.precise".localized).font(.headline)
            HStack {
                Button(action: { if hours > 0 { hours -= 0.5 } }) {
                    Image(systemName: "minus.circle.fill").font(.title).foregroundStyle(.red)
                }
                Spacer()
                Button(action: { hours = 40.0 }) {
                    Text("settings.display.standardHours".localized).padding(.vertical, 8).padding(.horizontal, 15)
                        .background(RoundedRectangle(cornerRadius: 20).stroke(Color.blue, lineWidth: 1))
                        .foregroundStyle(.blue)
                }
                Spacer()
                Button(action: { if hours < 80 { hours += 0.5 } }) {
                    Image(systemName: "plus.circle.fill").font(.title).foregroundStyle(.green)
                }
            }
        }
    }
}

#Preview {
    DisplaySettingsSection(settings: UserSettings.shared, activeSection: .constant(.display))
        .padding()
}
