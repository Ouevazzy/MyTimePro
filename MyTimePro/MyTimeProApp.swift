import SwiftUI
import SwiftData

@main
struct MyTimeProApp: App {
    @StateObject private var cloudService = CloudService.shared
    @StateObject private var userSettings = UserSettings()
    
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
                .environmentObject(userSettings)
        }
        .modelContainer(modelContainer)
        .environment(\.modelContext, modelContainer.mainContext)
    }
}
