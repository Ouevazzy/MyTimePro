import SwiftUI
import SwiftData

struct WorkDaysListView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var userSettings = UserSettings.shared
    
    // Fetch request pour les journées de travail non supprimées
    @Query(filter: #Predicate<WorkDay> { workDay in
        !workDay.isDeleted
    }, sort: \WorkDay.date, order: .reverse) private var workDays: [WorkDay]
    
    @State private var selectedWorkDay: WorkDay? = nil
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var showingConfirmationDialog = false
    @State private var indexToDelete: IndexSet?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(workDays) { workDay in
                    WorkDayRowView(workDay: workDay)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedWorkDay = workDay
                            showingEditSheet = true
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteWorkDay(workDay)
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                }
            }
            .navigationTitle("Liste des journées")
            .toolbar {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                NavigationStack {
                    AddEditWorkDayView(workDay: nil)
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                if let workDay = selectedWorkDay {
                    NavigationStack {
                        AddEditWorkDayView(workDay: workDay)
                    }
                }
            }
            .confirmationDialog(
                "Êtes-vous sûr de vouloir supprimer cet élément ?",
                isPresented: $showingConfirmationDialog,
                titleVisibility: .visible
            ) {
                Button("Supprimer", role: .destructive) {
                    if let indexSet = indexToDelete {
                        deleteItems(at: indexSet)
                    }
                }
            }
        }
    }
    
    private func deleteWorkDay(_ workDay: WorkDay) {
        // Utilisation de la suppression sécurisée
        workDay.markAsDeleted()
        do {
            try modelContext.save()
        } catch {
            print("❌ Erreur lors de la suppression : \(error)")
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let workDay = workDays[index]
            deleteWorkDay(workDay)
        }
    }
}

struct WorkDayRowView: View {
    let workDay: WorkDay
    @StateObject private var userSettings = UserSettings.shared
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(workDay.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                Text(workDay.type.rawValue)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if workDay.type.isWorkDay {
                VStack(alignment: .trailing) {
                    Text(workDay.formattedTotalHours)
                        .font(.headline)
                    
                    if workDay.overtimeSeconds != 0 {
                        Text(workDay.formattedOvertimeHours)
                            .foregroundStyle(Color.red)
                    }
                }
            }
            
            if !workDay.type.isWorkDay {
                Image(systemName: workDay.type.icon)
                    .foregroundStyle(workDay.type.color)
            }
        }
    }
}
