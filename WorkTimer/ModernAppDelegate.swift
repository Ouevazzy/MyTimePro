import UIKit
import CloudKit
import BackgroundTasks

class ModernAppDelegate: NSObject, UIApplicationDelegate {
    // Clés UserDefaults pour le verrouillage global
    private static let taskRegistrationLockKey = "com.mytiempo.taskRegistrationComplete"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Désactivé temporairement pour diagnostic
        // registerTaskHandlersIfNeeded()
        
        // Configurer les notifications push et vérifier la première installation
        setupPushNotifications()
        checkFirstInstall()
        return true
    }
    
    // Cette méthode ne fait qu'enregistrer les gestionnaires, mais ne planifie pas les tâches
    private func registerTaskHandlersIfNeeded() {
        // Désactivé temporairement pour diagnostiquer le problème
        print("⚠️ Enregistrement des tâches d'arrière-plan désactivé pour diagnostic")
        return
        
        // Le code ci-dessous est désactivé
        /* 
        // Vérifier si les tâches sont déjà enregistrées via UserDefaults
        let defaults = UserDefaults.standard
        
        // Si nous sommes dans un environnement de développement/débogage, forcer la réinitialisation
        #if DEBUG
        if ProcessInfo.processInfo.environment["RESET_TASK_REGISTRATION"] == "1" {
            defaults.removeObject(forKey: ModernAppDelegate.taskRegistrationLockKey)
            print("Réinitialisation forcée de l'enregistrement des tâches")
        }
        #endif
        
        // Vérifier si l'enregistrement a déjà été effectué
        if defaults.bool(forKey: ModernAppDelegate.taskRegistrationLockKey) {
            print("Tâches d'arrière-plan déjà enregistrées précédemment")
            return
        }
        
        // Tenter d'enregistrer la tâche de synchronisation
        print("Tentative d'enregistrement des tâches d'arrière-plan...")
        
        // Utiliser DispatchQueue.main pour s'assurer que nous sommes sur le thread principal
        DispatchQueue.main.async {
            let syncResult = BGTaskScheduler.shared.register(
                forTaskWithIdentifier: "com.mytiempo.sync",
                using: nil
            ) { [weak self] task in
                guard let self = self else { return }
                self.handleSyncTask(task: task as! BGProcessingTask)
            }
            
            let cleanupResult = BGTaskScheduler.shared.register(
                forTaskWithIdentifier: "com.mytiempo.cleanup",
                using: nil
            ) { [weak self] task in
                guard let self = self else { return }
                self.handleCleanupTask(task: task as! BGProcessingTask)
            }
            
            // Si l'enregistrement a réussi, marquer comme complet dans UserDefaults
            if syncResult && cleanupResult {
                defaults.set(true, forKey: ModernAppDelegate.taskRegistrationLockKey)
                print("✅ Enregistrement des tâches d'arrière-plan réussi")
            } else {
                print("❌ Échec de l'enregistrement des tâches d'arrière-plan - Sync: \(syncResult), Cleanup: \(cleanupResult)")
            }
        }
        */
    }
    
    // Cette méthode peut être appelée pour planifier les tâches réelles
    func scheduleBackgroundTasks() {
        // Désactivé temporairement pour diagnostiquer le problème
        print("⚠️ Planification des tâches d'arrière-plan désactivée pour diagnostic")
        return
        
        /*
        // Vérifier d'abord si l'enregistrement des tâches a été effectué
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: ModernAppDelegate.taskRegistrationLockKey) else {
            print("⚠️ Impossible de planifier les tâches : les gestionnaires ne sont pas enregistrés")
            registerTaskHandlersIfNeeded()
            return
        }
        
        // Planifier la tâche de synchronisation
        let syncRequest = BGProcessingTaskRequest(identifier: "com.mytiempo.sync")
        syncRequest.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // 1 heure
        syncRequest.requiresNetworkConnectivity = true
        
        // Planifier la tâche de nettoyage
        let cleanupRequest = BGProcessingTaskRequest(identifier: "com.mytiempo.cleanup")
        cleanupRequest.earliestBeginDate = Date(timeIntervalSinceNow: 86400) // 24 heures
        cleanupRequest.requiresNetworkConnectivity = true
        
        do {
            try BGTaskScheduler.shared.submit(syncRequest)
            try BGTaskScheduler.shared.submit(cleanupRequest)
            print("✅ Tâches d'arrière-plan planifiées avec succès")
        } catch {
            print("❌ Échec de la planification des tâches d'arrière-plan: \(error)")
        }
        */
    }
    
    // Méthode utilitaire pour réinitialiser l'état d'enregistrement (utile pour le débogage)
    func resetTaskRegistration() {
        UserDefaults.standard.removeObject(forKey: ModernAppDelegate.taskRegistrationLockKey)
        print("🔄 État d'enregistrement des tâches réinitialisé")
    }
    
    private func setupPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    private func checkFirstInstall() {
        let keychain = KeychainHelper.shared
        let isFirstInstall = keychain.retrieve(for: "isFirstInstall") == nil
        
        if isFirstInstall {
            keychain.save("true", for: "isFirstInstall")
            UserDefaults.standard.set(false, forKey: "hasCompletedFirstSync")
        }
    }
    
    private func handleSyncTask(task: BGProcessingTask) {
        // Désactivé temporairement
        task.setTaskCompleted(success: false)
        
        /*
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                try await ModernCloudService.shared.sendChanges()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        */
    }
    
    private func handleCleanupTask(task: BGProcessingTask) {
        // Désactivé temporairement
        task.setTaskCompleted(success: false)
        
        /*
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                // Au lieu d'un cleanup explicite, on force une nouvelle synchronisation
                try await ModernCloudService.shared.sendChanges()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }
        */
    }
    
    // MARK: - Push Notifications
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Enregistrer le token pour les notifications push
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        
        if notification?.subscriptionID == "sync-changes" {
            Task {
                do {
                    try await ModernCloudService.shared.sendChanges()
                    completionHandler(.newData)
                } catch {
                    completionHandler(.failed)
                }
            }
        } else {
            completionHandler(.noData)
        }
    }
} 