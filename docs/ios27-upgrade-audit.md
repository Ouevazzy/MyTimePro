# Audit de préparation à iOS 27

Date de vérification : 13 septembre 2026.

## Périmètre

Cet audit couvre les documents Apple qui s'appliquent aux technologies réellement
utilisées par WorkTimer : iOS/iPadOS 27, Xcode 27, SwiftUI, SwiftData,
StoreKit 2, App Intents, WidgetKit, confidentialité et distribution App Store.
Il ne recense pas les API Apple non utilisées par l'application.

## Décisions d'intégration

| Sujet Apple | État dans WorkTimer | Décision |
| --- | --- | --- |
| SDK et soumission | Le projet cible iOS 26 et `SDKROOT = iphoneos`. | Conserver iOS 26 comme version minimale ; compiler et soumettre avec Xcode 27 / SDK iOS 27. |
| Sélection de `TabView` | La sélection était un entier persistant. | Corrigée : `WorkTimerTab` est typé et toute valeur persistée invalide revient à l'accueil avant le rendu de `TabView`. |
| Redimensionnement et iPhone Duo | SwiftUI, `TabView` et `NavigationStack` sont déjà utilisés ; aucune référence à `UIScreen` ou à l'orientation n'a été trouvée. | Pas de migration structurelle nécessaire. L'animation de confettis utilise maintenant la largeur réelle de la fenêtre. |
| Écran de lancement | `INFOPLIST_KEY_UILaunchScreen_Generation = YES` est présent dans les configurations Debug et Release. | Conforme, à confirmer dans l'archive générée avec Xcode 27. |
| SwiftData | `@Query`, `@ModelActor`, une migration de schéma et CloudKit sont utilisés. | Aucun changement de modèle nécessaire. Tester les migrations et la synchronisation sur iOS 27. |
| StoreKit 2 | Chargement des produits, écoute de `Transaction.updates`, contrôle des droits, restauration et fichier de configuration StoreKit sont présents. | Tester les trois produits, un achat en attente, la restauration et les renouvellements avec Xcode 27. |
| App Intents | Les actions Siri reposent sur `AppShortcutsProvider` et des intentions applicatives. | Compatibles. Ne pas indexer les journées de travail ou les rendre disponibles à Apple Intelligence sans décision produit et confidentialité explicite. |
| WidgetKit | Widget statique, sans paramètre `@UnionValue`. | Aucune action requise ; tester le rafraîchissement et les familles de widget sous iOS 27. |
| Confidentialité | Aucun SDK tiers n'est lié. Le manifeste déclare `UserDefaults` avec la raison `CA92.1`. | Conserver le manifeste et valider le rapport de confidentialité de l'archive avant l'envoi. |

## Documents Apple à suivre

- [iOS & iPadOS 27 Release Notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes) — changements de SDK, dont le comportement de `TabView`, SwiftData et WidgetKit.
- [Xcode 27 Release Notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes) — compatibilité de l'outil, SDK et Swift 6.4.
- [Soumettre une app à l'App Store](https://developer.apple.com/app-store/submitting/) — le SDK iOS/iPadOS 27 devient obligatoire pour les envois App Store Connect à partir d'avril 2027.
- [Préparer une app pour iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/) et les [Human Interface Guidelines iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) — redimensionnement, tailles de classes et zones sûres asymétriques.
- [Mises à jour SwiftData](https://developer.apple.com/documentation/updates/swiftdata) — nouveaux observateurs et correctifs de concurrence.
- [Mises à jour App Intents](https://developer.apple.com/documentation/Updates/AppIntents) — intégration Siri, Raccourcis et Apple Intelligence.
- [StoreKit 2](https://developer.apple.com/storekit/) — tests d'achat et affichage des produits.
- [Décrire l'utilisation des API à raison requise](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) — manifeste de confidentialité requis lors de l'envoi.

## Vérification avant publication

1. Installer Xcode 27 RC (ou une version finale plus récente) sur un Mac Apple silicon sous macOS Tahoe 26.4 ou ultérieur.
2. Construire l'app et le widget avec le SDK iOS 27, sans changer `IPHONEOS_DEPLOYMENT_TARGET = 26.0`.
3. Exécuter la suite de tests puis vérifier, dans le simulateur, l'accueil, le calendrier, les feuilles, les achats et le widget.
4. Tester les largeurs étroites et larges dans le simulateur redimensionnable et, lorsque disponible, chaque pose d'iPhone Duo.
5. Créer une archive, contrôler le manifeste de confidentialité et l'écran de lancement généré, puis envoyer d'abord à TestFlight.
