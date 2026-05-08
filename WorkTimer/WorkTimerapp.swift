import SwiftUI
import SwiftData
import CloudKit
import UIKit

@main
struct WorkTimerApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: ModernAppDelegate
    private let cloudService = ModernCloudService.shared
    @State private var initialSetupComplete = false
    @Environment(\.scenePhase) var scenePhase
    @State private var firstLaunchManager = FirstLaunchManager()
    
    // Variable pour stocker le container une fois qu'il est créé
    let container: ModelContainer
    private let isCloudKitEnabled: Bool

    init() {
        UserDefaults.standard.set(false, forKey: "com.apple.CoreData.CloudKitDebug")
        UserDefaults.standard.set(false, forKey: "com.apple.CoreData.Logging.stderr")
        UserDefaults.standard.set(0, forKey: "com.apple.CoreData.SQLDebug")

        let schema = Schema([WorkDay.self])
        var cloudEnabled = false

        do {
            #if DEBUG
            AppLogger.debug("Mode DEBUG : CloudKit désactivé", category: AppLogger.cloudKit)
            let modelConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            #else
            AppLogger.info("Mode RELEASE : CloudKit activé", category: AppLogger.cloudKit)
            let modelConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .private("iCloud.jordan-payez.MyTimePro")
            )
            cloudEnabled = true
            #endif

            container = try ModelContainer(
                for: schema,
                migrationPlan: WorkDayMigrationPlan.self,
                configurations: modelConfig
            )
            container.mainContext.autosaveEnabled = false
            AppLogger.info("ModelContainer initialisé avec succès", category: AppLogger.data)

        } catch {
            AppLogger.error("Failed to initialize ModelContainer", category: AppLogger.data, error: error)
            cloudEnabled = false
            do {
                let fallbackConfig = ModelConfiguration(
                    schema: Schema([WorkDay.self]),
                    isStoredInMemoryOnly: false,
                    allowsSave: true
                )
                container = try ModelContainer(
                    for: Schema([WorkDay.self]),
                    migrationPlan: WorkDayMigrationPlan.self,
                    configurations: fallbackConfig
                )
                AppLogger.warning("ModelContainer de secours initialisé (sans CloudKit)", category: AppLogger.data)
            } catch {
                fatalError("Could not initialize ModelContainer: \(error)")
            }
        }

        isCloudKitEnabled = cloudEnabled
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environment(cloudService)
                .task {
                    // Différer les initialisations lourdes APRÈS le premier frame (Apple: cible 400ms)
                    guard !initialSetupComplete else { return }
                    initialSetupComplete = true

                    // 🧹 Nettoyage des entrées fantômes (0h00) au lancement
                    cleanupGhostEntries()

                    // Crash reporting & analytics — non bloquant
                    CrashReporting.shared.configure()
                    Analytics.shared.logScreenView("app_launch")

                    // Service cloud — initialisé après le rendu
                    AppLogger.info("Configuration initiale du service cloud", category: AppLogger.cloudKit)
                    cloudService.setModelContext(container.mainContext)
                    #if DEBUG
                    AppLogger.debug("Mode DEBUG : CloudKit désactivé", category: AppLogger.cloudKit)
                    #else
                    if isCloudKitEnabled {
                        cloudService.initialize()
                    } else {
                        AppLogger.warning("ModelContainer sans CloudKit — sync désactivée", category: AppLogger.cloudKit)
                    }
                    #endif
                }
                .sheet(isPresented: $firstLaunchManager.showFirstSyncInfo) {
                    FirstSyncInfoView(isPresented: $firstLaunchManager.showFirstSyncInfo)
                        .onDisappear {
                            firstLaunchManager.markFirstSyncCompleted()
                        }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        NotificationService.shared.clearBadge()
                    case .background:
                        // ⚠️ PAS de save automatique au background.
                        // Le mainContext a autosave=false pour éviter les entrées fantômes.
                        // Toute sauvegarde est faite explicitement (saveWorkDay, deleteWorkDay, etc.)
                        appDelegate.scheduleBackgroundTasks()
                    default:
                        break
                    }
                }
        }
    }
    
    /// Supprime les entrées fantômes : WorkDay de type travail avec 0h et sans horaires
    private func cleanupGhostEntries() {
        let ctx = container.mainContext
        let workType = WorkDayType.work.rawValue
        do {
            // Prédicat simplifié pour aider le compilateur Swift
            let predicate = #Predicate<WorkDay> {
                $0.totalHours == 0 && $0.typeRawValue == workType
            }
            let descriptor = FetchDescriptor<WorkDay>(predicate: predicate)

            let candidates = try ctx.fetch(descriptor)
            // Filtrage supplémentaire en mémoire
            let ghosts = candidates.filter { $0.startTime == nil }
            guard !ghosts.isEmpty else { return }

            for ghost in ghosts {
                AppLogger.warning("Suppression entrée fantôme: \(ghost.date)", category: AppLogger.data)
                ctx.delete(ghost)
            }
            try ctx.save()
            AppLogger.info("\(ghosts.count) entrée(s) fantôme(s) supprimée(s)", category: AppLogger.data)
        } catch {
            AppLogger.error("Échec nettoyage entrées fantômes", category: AppLogger.data, error: error)
        }
    }
}

// MARK: - Preview Support
struct MyTimeProApp_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .modelContainer(for: WorkDay.self, inMemory: true)
    }
}
