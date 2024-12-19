import SwiftUI

struct WeeklyHoursPickerView: View {
    @Binding var weeklyHours: Double
    
    var body: some View {
        Form {
            Section(header: Text("Heures hebdomadaires")) {
                Slider(value: $weeklyHours, in: 0...60, step: 0.5) {
                    Text("\(weeklyHours, specifier: "%.1f") heures")
                }
                Text("\(weeklyHours, specifier: "%.1f") heures")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Heures hebdomadaires")
    }
}
