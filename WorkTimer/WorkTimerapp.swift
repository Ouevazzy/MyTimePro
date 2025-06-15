import SwiftUI
import SwiftData
import CloudKit
import UIKit

@main
struct WorkTimerApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: ModernAppDelegate
    private let cloudService = ModernCloudService.shared
    @State private var initialSetupComplete = false
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var firstLaunchManager = FirstLaunchManager()
    
    // Variable pour stocker le container une fois qu'il est créé
    let container: ModelContainer
    
    init() {
        // Désactiver les logs verbeux de CoreData
        UserDefaults.standard.set(false, forKey: "com.apple.CoreData.CloudKitDebug")
        UserDefaults.standard.set(false, forKey: "com.apple.CoreData.Logging.stderr")
        UserDefaults.standard.set(0, forKey: "com.apple.CoreData.SQLDebug")
        
        // Configurer CoreData
        print("👋 Initialisation de WorkTimerApp")
        
        do {
            let schema = Schema([WorkDay.self])
            
            // Variable pour stocker la configuration du modèle
            var modelConfig: ModelConfiguration
            
            #if DEBUG
            // En mode DEBUG, ne pas utiliser CloudKit pour faciliter le développement
            print("🔄 Mode DEBUG : CloudKit désactivé")
            modelConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            #else
            // En mode RELEASE, utiliser CloudKit
            print("🔄 Mode RELEASE : CloudKit activé")
            
            // Vérification de l'unicité pour éviter les conflits d'initialisation CloudKit
            // Utiliser un verrou d'application plus fiable à travers les processus
            let hasInitializedCloudKit = UserDefaults.standard.bool(forKey: "hasInitializedCloudKit")
            
            if hasInitializedCloudKit {
                print("⚠️ Une configuration CloudKit existe déjà - utilisation d'une configuration sans CloudKit")
                modelConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true
                )
            } else {
                print("✅ Première initialisation CloudKit")
                // Marquer comme initialisé AVANT la création pour éviter les conflits
                UserDefaults.standard.set(true, forKey: "hasInitializedCloudKit")
                
                modelConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    allowsSave: true,
                    cloudKitDatabase: .private("iCloud.jordan-payez.MyTimePro")
                )
            }
            #endif
            
            // Création du ModelContainer avec la configuration appropriée
            container = try ModelContainer(for: schema, configurations: modelConfig)
            container.mainContext.autosaveEnabled = true
            print("✅ ModelContainer initialisé avec succès")
            
        } catch {
            print("❌ Failed to initialize ModelContainer: \(error.localizedDescription)")
            
            // En cas d'erreur, réinitialiser le verrou pour permettre une nouvelle tentative
            UserDefaults.standard.set(false, forKey: "hasInitializedCloudKit")
            
            // Créer un ModelContainer de secours sans CloudKit
            do {
                let fallbackConfig = ModelConfiguration(
                    schema: Schema([WorkDay.self]),
                    isStoredInMemoryOnly: false,
                    allowsSave: true
                )
                container = try ModelContainer(for: Schema([WorkDay.self]), configurations: fallbackConfig)
                print("✅ ModelContainer de secours initialisé")
            } catch {
                fatalError("Could not initialize ModelContainer: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .environmentObject(cloudService)
                .onAppear {
                    // Première mise à jour de l'icône — une fois que le ColorScheme est connu
                    updateAppIcon(for: colorScheme == .dark ? .dark : .light)
                    
                    // Initialiser le service de synchronisation une seule fois au démarrage 
                    if !initialSetupComplete {
                        print("🚀 Configuration initiale du service cloud")
                        cloudService.setModelContext(container.mainContext)
                        #if DEBUG
                        print("⚠️ Mode DEBUG : Initialisation du service cloud désactivée")
                        #else
                        // Ne pas utiliser de clé différente, c'est redondant et source de conflits
                        if !UserDefaults.standard.bool(forKey: "hasInitializedCloudKit") {
                            // Si pas de CloudKit initialisé, ne pas initialiser le service non plus
                            print("⚠️ Pas de service cloud initialisé - synchronisation CloudKit désactivée")
                        } else {
                            cloudService.initialize()
                        }
                        #endif
                        initialSetupComplete = true
                    }
                }
                .onChange(of: colorScheme) { _, newColorScheme in
                    print("ColorScheme changed to: \(newColorScheme)")
                    Task {
                        // Attendre un peu avant de changer l'icône
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        updateAppIcon(for: newColorScheme == .dark ? .dark : .light)
                    }
                }
                .sheet(isPresented: $firstLaunchManager.showFirstSyncInfo) {
                    FirstSyncInfoView(isPresented: $firstLaunchManager.showFirstSyncInfo)
                        .onDisappear {
                            firstLaunchManager.markFirstSyncCompleted()
                        }
                }
        }
    }
    
    private func updateAppIcon(for style: UIUserInterfaceStyle) {
        // nil = icône primaire (claire) ; "AppIconDark" = variante sombre
        let desiredIconName: String? = (style == .dark) ? "AppIconDark" : nil
        print("🔄 Attempting to change app icon to: \(desiredIconName ?? "Primary")")
        
        guard UIApplication.shared.supportsAlternateIcons else {
            print("❌ Device does not support alternate icons")
            return
        }
        
        // Vérifier si l'icône actuelle est déjà celle souhaitée
        let currentIcon = UIApplication.shared.alternateIconName ?? "AppIcon"
        print("📱 Current icon: \(currentIcon)")
        
        if currentIcon == (desiredIconName ?? "AppIcon") {
            print("✅ Icon is already set to: \(desiredIconName ?? "Primary")")
            return
        }
        
        // Vérifier si l'application est en arrière-plan
        if UIApplication.shared.applicationState == .background {
            print("⚠️ App is in background, postponing icon change")
            NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                print("🔄 App became active, retrying icon change to: \(desiredIconName ?? "Primary")")
                self.updateAppIcon(for: style)
            }
            return
        }
        
        // Vérifier si les icônes alternatives sont disponibles dans le bundle
        guard let bundleIcons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let alternateIcons = bundleIcons["CFBundleAlternateIcons"] as? [String: Any],
              (desiredIconName == nil || alternateIcons[desiredIconName!] != nil) else {
            print("❌ Icon \(desiredIconName ?? "Primary") not found in Info.plist")
            return
        }
        
        print("🔄 Setting alternate icon to: \(desiredIconName ?? "Primary")")
        
        // Utiliser le thread principal pour le changement d'icône
        DispatchQueue.main.async {
            UIApplication.shared.setAlternateIconName(desiredIconName) { error in
                if let error = error {
                    print("❌ Error setting icon: \(error.localizedDescription)")
                    // Réessayer après un délai en cas d'échec
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        print("🔄 Retrying icon change to: \(desiredIconName ?? "Primary")")
                        self.updateAppIcon(for: style)
                    }
                } else {
                    print("✅ Successfully changed app icon to: \(desiredIconName ?? "Primary")")
                }
            }
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
