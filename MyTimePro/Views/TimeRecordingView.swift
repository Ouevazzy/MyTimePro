import SwiftUI
import CloudKit

struct TimeRecordingView: View {
    @StateObject private var viewModel = TimeRecordingViewModel()
    
    var body: some View {
        List {
            Section(header: Text("Enregistrement du temps")) {
                DatePicker("Date", selection: $viewModel.selectedDate, displayedComponents: [.date])
                
                HStack {
                    Text("Début")
                    Spacer()
                    DatePicker("", selection: $viewModel.startTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                }
                
                HStack {
                    Text("Fin")
                    Spacer()
                    DatePicker("", selection: $viewModel.endTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                }
                
                if let duration = viewModel.duration {
                    HStack {
                        Text("Durée")
                        Spacer()
                        Text(duration)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Button(action: viewModel.saveTime) {
                    HStack {
                        Spacer()
                        Text("Enregistrer")
                        Spacer()
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
        .navigationTitle("Enregistrement")
        .alert("Message", isPresented: $viewModel.showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}
