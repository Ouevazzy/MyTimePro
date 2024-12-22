struct WeeklyHoursPickerView: View {
    @Binding var hours: Double
    @Binding var isPresented: Bool
    let onSave: (Double) -> Void
    
    var body: some View {
        Form {
            Stepper(value: $hours, in: 0...80, step: 0.5) {
                HStack {
                    Text("Heures par semaine")
                    Spacer()
                    Text("\(hours, specifier: "%.1f")h")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .navigationTitle("Heures hebdomadaires")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Annuler") {
                    isPresented = false
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Enregistrer") {
                    onSave(hours)
                    isPresented = false
                }
            }
        }
    }
}

struct VacationDetailsView: View {
    let stats: (used: Double, remaining: Double)
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    DetailRow(
                        title: "Jours restants",
                        value: stats.remaining,
                        icon: "calendar.badge.clock",
                        color: .blue
                    )
                    
                    DetailRow(
                        title: "Jours utilisés",
                        value: stats.used,
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }
            }
            .navigationTitle("Détails des congés")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            
            Spacer()
            
            Text(String(format: "%.1f j", value))
                .foregroundColor(.secondary)
        }
    }
}

extension Double {
    func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension Bundle {
    var appVersionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: WorkDay.self, inMemory: true)
}