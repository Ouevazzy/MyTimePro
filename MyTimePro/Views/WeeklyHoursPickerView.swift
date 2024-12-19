import SwiftUI

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