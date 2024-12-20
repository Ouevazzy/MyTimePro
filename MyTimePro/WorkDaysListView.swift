import SwiftUI
import SwiftData

struct WorkDaysListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]
    @StateObject private var cloudService = CloudService.shared
    
    var body: some View {
        NavigationView {
            List {
                ForEach(workDays) { workDay in
                    NavigationLink {
                        AddEditWorkDayView(workDay: workDay)
                    } label: {
                        WorkDayRow(workDay: workDay)
                    }
                }
                .onDelete(perform: deleteWorkDays)
            }
            .navigationTitle("Historique")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        addWorkDay()
                    } label: {
                        Label("Ajouter", systemImage: "plus")
                    }
                }
            }
        }
    }
    
    private func deleteWorkDays(at offsets: IndexSet) {
        for index in offsets {
            let workDay = workDays[index]
            modelContext.delete(workDay)
            
            // Supprimer également de CloudKit
            Task {
                do {
                    try await cloudService.deleteWorkDay(workDay)
                } catch {
                    print("Erreur lors de la suppression dans CloudKit: \(error)")
                }
            }
        }
    }
    
    private func addWorkDay() {
        withAnimation {
            let newWorkDay = WorkDay()
            modelContext.insert(newWorkDay)
            
            // Sauvegarder dans CloudKit
            Task {
                do {
                    try await cloudService.saveWorkDay(newWorkDay)
                } catch {
                    print("Erreur lors de la sauvegarde dans CloudKit: \(error)")
                }
            }
        }
    }
}

struct WorkDayRow: View {
    let workDay: WorkDay
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(workDay.date, style: .date)
                .font(.headline)
            HStack {
                Text(workDay.startTime, style: .time)
                Text("-")
                Text(workDay.endTime, style: .time)
            }
            .font(.subheadline)
        }
    }
}
