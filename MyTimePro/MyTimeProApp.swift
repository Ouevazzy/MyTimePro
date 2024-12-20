import SwiftUI
import SwiftData

@main
struct MyTimeProApp: App {
    let cloudService = CloudService.shared
    let modelContainer: ModelContainer
    
    init() {
        do {
            modelContainer = try ModelContainer(for: WorkDay.self)
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .environment(\.modelContext, modelContainer.mainContext)
    }
}
