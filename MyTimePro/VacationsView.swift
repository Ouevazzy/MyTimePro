import SwiftUI
import SwiftData

struct VacationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<WorkDay> { workDay in
        workDay.isVacation == true
    }, sort: \WorkDay.date) private var vacations: [WorkDay]
    @StateObject private var cloudService = CloudService.shared
    
    var body: some View {
        List {
            ForEach(vacations) { vacation in
                VacationRow(vacation: vacation)
            }
            .onDelete(perform: deleteVacations)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    addVacation()
                } label: {
                    Label("Ajouter", systemImage: "plus")
                }
            }
        }
    }
    
    private func deleteVacations(at offsets: IndexSet) {
        for index in offsets {
            let vacation = vacations[index]
            modelContext.delete(vacation)
            
            Task {
                do {
                    try await cloudService.deleteWorkDay(vacation)
                } catch {
                    print("Erreur lors de la suppression des vacances: \(error)")
                }
            }
        }
    }
    
    private func addVacation() {
        let newVacation = WorkDay(isVacation: true)
        modelContext.insert(newVacation)
        
        Task {
            do {
                try await cloudService.saveWorkDay(newVacation)
            } catch {
                print("Erreur lors de la sauvegarde des vacances: \(error)")
            }
        }
    }
}

struct VacationRow: View {
    let vacation: WorkDay
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(vacation.date, style: .date)
                .font(.headline)
            if let type = vacation.vacationType {
                Text(type.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
