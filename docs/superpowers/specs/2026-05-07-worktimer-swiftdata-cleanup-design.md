# WorkTimer — SwiftData Cleanup & Distribution Prep

**Date:** 2026-05-07  
**Status:** Approved  
**Goal:** Supprimer les champs legacy de WorkDay, migrer le schéma SwiftData proprement, corriger les performances de StatsView, et nettoyer les entitlements — sans risque pour les données utilisateurs existantes.

---

## Context

L'app est déjà sur l'App Store. Elle utilise 100% SwiftData (zéro CoreData applicatif). Les 3 lignes `com.apple.CoreData.*` dans WorkTimerapp.swift sont des clés UserDefaults pour silencer les logs internes de SwiftData — elles restent.

La sync CloudKit est entièrement gérée par SwiftData via `ModelConfiguration(cloudKitDatabase: .private("iCloud.jordan-payez.MyTimePro"))` en mode RELEASE. Pas de CKSyncEngine custom, pas de CKRecord manuel — c'est correct.

---

## Section 1 — Migration SwiftData V1 → V2

### Champs supprimés de `WorkDay`

| Champ | Type | Raison |
|---|---|---|
| `needsSync` | `Bool = true` | Legacy sync manuelle — SwiftData gère en interne |
| `cloudKitRecordID` | `String?` | ID CloudKit stocké manuellement — inutile avec SwiftData |
| `isDeleted` | `Bool = false` | Soft-delete manuel — SwiftData + CloudKit gèrent les tombstones |

### Méthode de migration

Migration **lightweight** via `SchemaMigrationPlan`. Aucun bloc custom nécessaire : les 3 champs ont des valeurs par défaut (Bool a `false`/`true`, String? a `nil`), SwiftData sait les supprimer seul.

### Fichiers créés

- `WorkTimer/WorkDaySchemaV1.swift` — snapshot figé du modèle V1 (avec les 3 champs)
- `WorkTimer/WorkDaySchemaV2.swift` — modèle V2 (sans les 3 champs)
- `WorkTimer/WorkDayMigrationPlan.swift` — `SchemaMigrationPlan` V1 → V2

### Impact CloudKit

Les records existants en iCloud conservent les anciens champs (`CD_needsSync`, `CD_cloudKitRecordID`, `CD_isDeleted`). SwiftData les ignore après migration. Aucune perte de données, aucune action manuelle dans le CloudKit Dashboard.

---

## Section 2 — Nettoyage WorkDay.swift

Suppressions dans `WorkDay.swift` :
- Propriétés : `needsSync`, `cloudKitRecordID`, `isDeleted`
- Méthode : `markSynced()`
- Computed property : `shouldSync`
- Lignes `needsSync = true` dans `calculateHours()` et `init()`
- Paramètre `cloudKitRecordID` dans `init()`

Le reste du modèle est intact.

---

## Section 3 — Mise à jour des FetchDescriptors

Tous les prédicats contenant `$0.isDeleted == false` sont simplifiés. Fichiers concernés :

- `WorkTimerapp.swift` — `cleanupGhostEntries()`
- `HomeTabView.swift` — `@Query` + FetchDescriptor dans `loadStats()`
- `StatsView.swift` — `fetchWorkDays()`
- `WorkDaysListView.swift` — tous les FetchDescriptors
- `CalendarView.swift` — tous les FetchDescriptors

---

## Section 4 — Performance StatsView

### Problème

`yearlyStats` et `monthlyStats` sont des computed properties sur `StatsView` → SwiftUI les recalcule à chaque render, même si `selectedYear` n'a pas changé.

### Solution

Passer en `@State` + `.task(id: selectedYear)` :

```swift
@State private var yearlyStats: YearStats = YearStats.empty
@State private var monthlyStats: [MonthStats] = []

.task(id: selectedYear) {
    yearlyStats = calculateYearStats(for: selectedYear)
    monthlyStats = (1...12).map { calculateMonthStats(year: selectedYear, month: $0) }
}
```

Le calcul ne tourne que quand `selectedYear` change ou que la vue apparaît — plus sur chaque render.

---

## Section 5 — Nettoyage Entitlements

Retirer `CloudDocuments` de `com.apple.developer.icloud-services` dans `WorkTimer.entitlements`.  
L'app n'utilise pas iCloud Documents (pas de `NSUbiquitousDocumentsDirectory`, pas de `NSFileManager` iCloud Documents API).

---

## Section 6 — Nettoyage WorkTimerapp.swift

- Brancher `WorkDayMigrationPlan` sur le `ModelContainer`
- Remplacer la clé UserDefaults `hasInitializedCloudKit` par une propriété `private let isCloudKitEnabled: Bool` sur `WorkTimerApp` — définie à `true` si ModelContainer init avec CloudKit réussit, `false` en fallback. Plus propre qu'un UserDefaults pour de la communication intra-init.
- Garder les 3 lignes `com.apple.CoreData.*` UserDefaults (nécessaires pour silencer SwiftData)

---

## Section 7 — Git

Un seul commit couvrant : migration schéma + nettoyage code + entitlements + performance.

---

## Contraintes & risques

- **Schema change safe** : lightweight migration, pas de custom block, champs avec defaults → risque minimal
- **CloudKit backward compat** : les vieux records en iCloud ont encore les anciens champs, l'app les ignore → aucun conflit
- **Pas de changement de container ID** : `iCloud.jordan-payez.MyTimePro` reste inchangé partout
- **autosaveEnabled = false** : reste `false` — le fix ghost entries doit rester explicite
