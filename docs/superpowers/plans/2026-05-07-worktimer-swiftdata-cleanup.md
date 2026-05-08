# WorkTimer SwiftData Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Supprimer les 3 champs legacy de WorkDay via une migration SwiftData lightweight, nettoyer tous les FetchDescriptors, améliorer la performance de StatsView, et nettoyer les entitlements — sans risque pour les données utilisateurs existantes.

**Architecture:** Migration SwiftData V1→V2 via `SchemaMigrationPlan` lightweight (aucun bloc custom). SwiftData gère la sync CloudKit automatiquement via `ModelConfiguration(cloudKitDatabase:)` en RELEASE — aucun changement à cette architecture. Les records iCloud existants conservent les anciens champs mais l'app les ignore après migration.

**Tech Stack:** SwiftData, CloudKit (via SwiftData), Swift 6, SwiftUI, iOS 17+

---

## File Map

| Fichier | Action | Rôle |
|---|---|---|
| `WorkTimer/WorkDaySchemaV1.swift` | **Créer** | Snapshot figé du modèle V1 (avec les 3 champs legacy) |
| `WorkTimer/WorkDayMigrationPlan.swift` | **Créer** | SchemaMigrationPlan V1→V2 |
| `WorkTimer/WorkDay.swift` | **Modifier** | Supprimer 3 champs + méthodes legacy, mettre à jour #Index |
| `WorkTimer/WorkTimerapp.swift` | **Modifier** | Brancher migration plan, remplacer UserDefaults par isCloudKitEnabled |
| `WorkTimer/StatsView.swift` | **Modifier** | Retirer isDeleted des prédicats + perf @State |
| `WorkTimer/HomeTabView.swift` | **Modifier** | Retirer isDeleted des prédicats |
| `WorkTimer/WorkDaysListView.swift` | **Modifier** | Retirer isDeleted des 3 prédicats |
| `WorkTimer/CalendarView.swift` | **Modifier** | Retirer isDeleted des 2 prédicats |
| `WorkTimer/StatsCache.swift` | **Modifier** | Retirer !$0.isDeleted des 2 filtres en mémoire |
| `WorkTimer/ModernCloudService.swift` | **Modifier** | Retirer ligne UserDefaults hasInitializedCloudKit stale |
| `WorkTimer/WorkTimer.entitlements` | **Modifier** | Retirer CloudDocuments |

---

## Task 1 : Créer WorkDaySchemaV1.swift — snapshot V1

**Files:**
- Create: `WorkTimer/WorkDaySchemaV1.swift`

- [ ] **Step 1 : Créer le fichier snapshot**

```swift
import SwiftData
import Foundation

enum WorkDaySchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [WorkDay.self]

    @Model
    final class WorkDay {
        #Index<WorkDay>([\.date], [\.typeRawValue], [\.isDeleted], [\.needsSync], [\.date, \.isDeleted])

        var id: UUID = UUID()
        var cloudKitRecordID: String?
        var createdAt: Date = Date()
        var modifiedAt: Date = Date()
        var isDeleted: Bool = false
        var needsSync: Bool = true
        var date: Date = Date()
        var startTime: Date?
        var endTime: Date?
        var breakDuration: TimeInterval = 3600
        var totalHours: Double = 0.0
        var overtimeSeconds: Int = 0
        var typeRawValue: String = "work"
        var note: String?
        var bonusAmount: Double = 0.0
    }
}
```

---

## Task 2 : Créer WorkDayMigrationPlan.swift

**Files:**
- Create: `WorkTimer/WorkDayMigrationPlan.swift`

- [ ] **Step 1 : Créer le V2 schema + plan de migration**

```swift
import SwiftData

enum WorkDaySchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] = [WorkDay.self]
}

enum WorkDayMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [
        WorkDaySchemaV1.self,
        WorkDaySchemaV2.self
    ]

    static var stages: [MigrationStage] = [migrateV1toV2]

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: WorkDaySchemaV1.self,
        toVersion: WorkDaySchemaV2.self
    )
}
```

---

## Task 3 : Nettoyer WorkDay.swift — supprimer champs legacy

**Files:**
- Modify: `WorkTimer/WorkDay.swift`

- [ ] **Step 1 : Remplacer tout le contenu du fichier**

```swift
import Foundation
import SwiftData
import SwiftUI

@Model
final class WorkDay {
    #Index<WorkDay>([\.date], [\.typeRawValue])

    // MARK: - Properties
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var date: Date = Date()
    var startTime: Date?
    var endTime: Date?
    var breakDuration: TimeInterval = 3600
    var totalHours: Double = 0.0
    var overtimeSeconds: Int = 0
    var typeRawValue: String = WorkDayType.work.rawValue
    var note: String?
    var bonusAmount: Double = 0.0

    // MARK: - Computed Properties
    var type: WorkDayType {
        get { WorkDayType(rawValue: typeRawValue) ?? .work }
        set { typeRawValue = newValue.rawValue }
    }

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        startTime: Date? = nil,
        endTime: Date? = nil,
        breakDuration: TimeInterval = 3600,
        totalHours: Double = 0.0,
        overtimeSeconds: Int = 0,
        type: WorkDayType = .work,
        note: String? = nil,
        bonusAmount: Double = 0.0
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.breakDuration = breakDuration
        self.totalHours = totalHours
        self.overtimeSeconds = overtimeSeconds
        self.type = type
        self.note = note
        self.bonusAmount = bonusAmount
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    // MARK: - Public Methods
    func calculateHours() {
        let settings = UserSettings.shared
        let calendar = Calendar.current
        var standardSeconds = 0

        if type == .work || type == .compensatory {
            let weekday = calendar.component(.weekday, from: date)
            let adjustedWeekday = weekday == 1 ? 6 : weekday - 2
            if adjustedWeekday >= 0 && adjustedWeekday < settings.workingDays.count
                && settings.workingDays[adjustedWeekday] {
                standardSeconds = Int(round(settings.standardDailyHours * 3600))
            }
        }

        totalHours = 0
        overtimeSeconds = 0

        switch type {
        case .work:
            guard let start = startTime, let end = endTime else { return }
            let workedSeconds = max(0, end.timeIntervalSince(start) - breakDuration)
            totalHours = workedSeconds / 3600.0
            overtimeSeconds = Int(round(workedSeconds)) - standardSeconds
        case .vacation, .halfDayVacation, .sickLeave, .holiday:
            break
        case .compensatory:
            overtimeSeconds = -standardSeconds
        case .training:
            totalHours = Double(standardSeconds) / 3600.0
        }

        if !type.isWorkDay {
            startTime = nil
            endTime = nil
            breakDuration = 0
            bonusAmount = 0
        }

        modifiedAt = Date()
    }

    func updateData(startTime: Date?, endTime: Date?, breakDuration: TimeInterval) {
        if type.isWorkDay {
            self.startTime = startTime
            self.endTime = endTime
            if let s = startTime, let e = endTime, e >= s {
                let worked = max(0, e.timeIntervalSince(s))
                self.breakDuration = min(max(0, breakDuration), worked)
            } else {
                self.breakDuration = max(0, breakDuration)
            }
        }
        calculateHours()
    }

    // MARK: - Formatted Properties
    var formattedTotalHours: String {
        UserSettings.shared.useDecimalHours
            ? String(format: "%.2f", totalHours)
            : formatTimeInterval(totalHours * 3600)
    }

    var formattedOvertimeHours: String {
        UserSettings.shared.useDecimalHours
            ? String(format: "%.2f", Double(overtimeSeconds) / 3600.0)
            : formatTimeInterval(Double(overtimeSeconds))
    }

    // MARK: - Private Helpers
    private func formatTimeInterval(_ seconds: Double) -> String {
        let totalMinutes = Int(round(seconds / 60))
        let hours = abs(totalMinutes / 60)
        let minutes = abs(totalMinutes % 60)
        let sign = seconds < 0 ? "-" : ""
        return String(format: "%@%dh%02d", sign, hours, minutes)
    }
}

// MARK: - Validation
extension WorkDay {
    var isValid: Bool {
        if type.isWorkDay {
            guard let start = startTime, let end = endTime else { return false }
            guard end > start else { return false }
            guard breakDuration >= 0 else { return false }
            guard bonusAmount >= 0 else { return false }
            let duration = end.timeIntervalSince(start)
            guard duration <= 24 * 3600 else { return false }
            guard breakDuration <= duration else { return false }
        }
        let calendar = Calendar.current
        let maxFuture = calendar.date(byAdding: .year, value: 1,   to: Date()) ?? Date.distantFuture
        let minPast   = calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date.distantPast
        guard date >= minPast && date <= maxFuture else { return false }
        if let note = note, note.count > 500 { return false }
        return true
    }
}
```

---

## Task 4 : Brancher la migration dans WorkTimerapp.swift

**Files:**
- Modify: `WorkTimer/WorkTimerapp.swift`

- [ ] **Step 1 : Ajouter isCloudKitEnabled et brancher la migration**

Remplacer le `init()` complet par :

```swift
init() {
    UserDefaults.standard.set(false, forKey: "com.apple.CoreData.CloudKitDebug")
    UserDefaults.standard.set(false, forKey: "com.apple.CoreData.Logging.stderr")
    UserDefaults.standard.set(0, forKey: "com.apple.CoreData.SQLDebug")

    let schema = Schema([WorkDay.self])
    var cloudEnabled = false

    do {
        #if DEBUG
        let modelConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        #else
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
```

- [ ] **Step 2 : Ajouter la propriété isCloudKitEnabled à WorkTimerApp**

Juste après `let container: ModelContainer`, ajouter :

```swift
private let isCloudKitEnabled: Bool
```

- [ ] **Step 3 : Mettre à jour le .task {} — remplacer la vérification UserDefaults**

Remplacer le bloc `#else` dans le `.task {}` :

```swift
// Avant :
#else
if !UserDefaults.standard.bool(forKey: "hasInitializedCloudKit") {
    AppLogger.warning("Pas de service cloud initialisé...", category: AppLogger.cloudKit)
} else {
    cloudService.initialize()
}
#endif

// Après :
#else
if isCloudKitEnabled {
    cloudService.initialize()
} else {
    AppLogger.warning("ModelContainer sans CloudKit — sync désactivée", category: AppLogger.cloudKit)
}
#endif
```

- [ ] **Step 4 : Retirer !$0.isDeleted du filtre en mémoire dans cleanupGhostEntries()**

```swift
// Avant (ligne 142) :
let ghosts = candidates.filter { $0.startTime == nil && !$0.isDeleted }

// Après :
let ghosts = candidates.filter { $0.startTime == nil }
```

---

## Task 5 : Retirer isDeleted de StatsView.swift

**Files:**
- Modify: `WorkTimer/StatsView.swift`

- [ ] **Step 1 : Mettre à jour fetchWorkDays (ligne 265-270)**

```swift
// Avant :
let descriptor = FetchDescriptor<WorkDay>(
    predicate: #Predicate<WorkDay> {
        $0.date >= startDate && $0.date < endDate && $0.isDeleted == false
    },
    sortBy: [SortDescriptor(\.date, order: order)]
)

// Après :
let descriptor = FetchDescriptor<WorkDay>(
    predicate: #Predicate<WorkDay> {
        $0.date >= startDate && $0.date < endDate
    },
    sortBy: [SortDescriptor(\.date, order: order)]
)
```

- [ ] **Step 2 : Ajouter YearStats.empty à la fin du fichier (après la struct YearStats)**

```swift
struct YearStats {
    let workDays: Int
    let vacationDays: Double
    let sickDays: Int
    let totalHours: Double
    let overtimeSeconds: Int
    let totalBonus: Double

    static let empty = YearStats(workDays: 0, vacationDays: 0, sickDays: 0,
                                 totalHours: 0, overtimeSeconds: 0, totalBonus: 0)
}
```

- [ ] **Step 3 : Passer yearlyStats et monthlyStats en @State**

Dans le corps de `StatsView`, remplacer les computed properties :

```swift
// Avant :
var yearlyStats: YearStats {
    calculateYearStats(for: selectedYear)
}

var monthlyStats: [MonthStats] {
    (1...12).map { month in
        calculateMonthStats(year: selectedYear, month: month)
    }
}

// Après — deux @State dans la section State Properties :
@State private var yearlyStats: YearStats = .empty
@State private var monthlyStats: [MonthStats] = []
```

- [ ] **Step 4 : Ajouter .task(id: selectedYear) à la fin du body de StatsView**

Ajouter après `.toolbar { ... }` et avant la fermeture de `var body: some View` :

```swift
.task(id: selectedYear) {
    yearlyStats = calculateYearStats(for: selectedYear)
    monthlyStats = (1...12).map { calculateMonthStats(year: selectedYear, month: $0) }
}
```

---

## Task 6 : Retirer isDeleted de HomeTabView.swift

**Files:**
- Modify: `WorkTimer/HomeTabView.swift`

- [ ] **Step 1 : Mettre à jour le @Query (ligne 9-11)**

```swift
// Avant :
@Query(filter: #Predicate<WorkDay> {
    ($0.typeRawValue == "workDayType.vacation" || $0.typeRawValue == "workDayType.halfDayVacation") && !$0.isDeleted
}, sort: \WorkDay.date) private var vacationWorkDays: [WorkDay]

// Après :
@Query(filter: #Predicate<WorkDay> {
    $0.typeRawValue == "workDayType.vacation" || $0.typeRawValue == "workDayType.halfDayVacation"
}, sort: \WorkDay.date) private var vacationWorkDays: [WorkDay]
```

- [ ] **Step 2 : Mettre à jour le FetchDescriptor dans loadStats() (ligne ~135)**

```swift
// Avant :
$0.date >= startDate && $0.date < endDate && !$0.isDeleted

// Après :
$0.date >= startDate && $0.date < endDate
```

---

## Task 7 : Retirer isDeleted de WorkDaysListView.swift

**Files:**
- Modify: `WorkTimer/WorkDaysListView.swift`

- [ ] **Step 1 : Premier FetchDescriptor (ligne 441-446) — filtre de base**

```swift
// Avant :
predicate: #Predicate<WorkDay> { workDay in
    workDay.date >= startOfMonth &&
    workDay.date < endOfMonth &&
    workDay.isDeleted == false
},

// Après :
predicate: #Predicate<WorkDay> { workDay in
    workDay.date >= startOfMonth &&
    workDay.date < endOfMonth
},
```

- [ ] **Step 2 : Deuxième FetchDescriptor (ligne 516-522) — avec filtre type**

```swift
// Avant :
predicate: #Predicate<WorkDay> { workDay in
    workDay.date >= startOfMonth &&
    workDay.date < endOfMonth &&
    workDay.isDeleted == false &&
    workDay.typeRawValue == selectedTypeRawValue
},

// Après :
predicate: #Predicate<WorkDay> { workDay in
    workDay.date >= startOfMonth &&
    workDay.date < endOfMonth &&
    workDay.typeRawValue == selectedTypeRawValue
},
```

- [ ] **Step 3 : Troisième FetchDescriptor (ligne 526-532) — sans filtre type**

```swift
// Avant :
predicate: #Predicate<WorkDay> { workDay in
    workDay.date >= startOfMonth &&
    workDay.date < endOfMonth &&
    workDay.isDeleted == false
},

// Après :
predicate: #Predicate<WorkDay> { workDay in
    workDay.date >= startOfMonth &&
    workDay.date < endOfMonth
},
```

---

## Task 8 : Retirer isDeleted de CalendarView.swift

**Files:**
- Modify: `WorkTimer/CalendarView.swift`

- [ ] **Step 1 : Premier prédicat (ligne 556)**

```swift
// Avant :
predicate: #Predicate<WorkDay> { $0.date >= start && $0.date < end && $0.isDeleted == false },

// Après :
predicate: #Predicate<WorkDay> { $0.date >= start && $0.date < end },
```

- [ ] **Step 2 : Deuxième prédicat (ligne 565)**

```swift
// Avant :
predicate: #Predicate<WorkDay> { $0.date >= firstDay && $0.date <= lastDay && $0.isDeleted == false },

// Après :
predicate: #Predicate<WorkDay> { $0.date >= firstDay && $0.date <= lastDay },
```

---

## Task 9 : Retirer isDeleted de StatsCache.swift

**Files:**
- Modify: `WorkTimer/StatsCache.swift`

- [ ] **Step 1 : Filtre en mémoire ligne 239-241**

```swift
// Avant :
let yearWorkDays = workDays.filter {
    calendar.component(.year, from: $0.date) == year && !$0.isDeleted
}

// Après :
let yearWorkDays = workDays.filter {
    calendar.component(.year, from: $0.date) == year
}
```

- [ ] **Step 2 : Filtre en mémoire ligne 287-290**

```swift
// Avant :
let monthWorkDays = workDays.filter { day in
    let components = calendar.dateComponents([.year, .month], from: day.date)
    return components.year == year && components.month == month && !day.isDeleted
}

// Après :
let monthWorkDays = workDays.filter { day in
    let components = calendar.dateComponents([.year, .month], from: day.date)
    return components.year == year && components.month == month
}
```

---

## Task 10 : Nettoyer ModernCloudService.swift

**Files:**
- Modify: `WorkTimer/ModernCloudService.swift`

- [ ] **Step 1 : Retirer la ligne UserDefaults stale dans resetCloudKitInitialization() (ligne 149)**

```swift
// Avant :
func resetCloudKitInitialization() {
    UserDefaults.standard.set(false, forKey: "hasInitializedCloudKit")
    UserDefaults.standard.removeObject(forKey: "ckSyncEngineStateData")
    syncStatus = .idle
    userMessage = "État iCloud réinitialisé. Redémarrez l'application si nécessaire."
    AppLogger.info("État iCloud réinitialisé", category: AppLogger.cloudKit)
}

// Après :
func resetCloudKitInitialization() {
    UserDefaults.standard.removeObject(forKey: "ckSyncEngineStateData")
    syncStatus = .idle
    userMessage = "État iCloud réinitialisé. Redémarrez l'application si nécessaire."
    AppLogger.info("État iCloud réinitialisé", category: AppLogger.cloudKit)
}
```

---

## Task 11 : Nettoyer les entitlements

**Files:**
- Modify: `WorkTimer/WorkTimer.entitlements`

- [ ] **Step 1 : Retirer CloudDocuments de icloud-services**

```xml
<!-- Avant : -->
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
    <string>CloudDocuments</string>
</array>

<!-- Après : -->
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

---

## Task 12 : Build et vérification

- [ ] **Step 1 : Compiler le projet**

```bash
xcodebuild -project WorkTimer.xcodeproj -scheme WorkTimer \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Résultat attendu : `BUILD SUCCEEDED` sans aucune ligne `error:`.

- [ ] **Step 2 : Lancer les tests unitaires**

```bash
xcodebuild -project WorkTimer.xcodeproj -scheme WorkTimer \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  test 2>&1 | grep -E "passed|failed|error:"
```

Résultat attendu : tous les tests `passed`, aucun `failed`.

- [ ] **Step 3 : Vérifier qu'aucune référence isDeleted/needsSync/cloudKitRecordID ne reste**

```bash
grep -rn "isDeleted\|needsSync\|cloudKitRecordID\|hasInitializedCloudKit" WorkTimer/ --include="*.swift"
```

Résultat attendu : aucune ligne (0 matches).

---

## Task 13 : Commit final

- [ ] **Step 1 : Stager et commiter tous les changements**

```bash
git add WorkTimer/WorkDaySchemaV1.swift \
        WorkTimer/WorkDayMigrationPlan.swift \
        WorkTimer/WorkDay.swift \
        WorkTimer/WorkTimerapp.swift \
        WorkTimer/StatsView.swift \
        WorkTimer/HomeTabView.swift \
        WorkTimer/WorkDaysListView.swift \
        WorkTimer/CalendarView.swift \
        WorkTimer/StatsCache.swift \
        WorkTimer/ModernCloudService.swift \
        WorkTimer/WorkTimer.entitlements

git commit -m "$(cat <<'EOF'
Remove legacy sync fields via SwiftData V1→V2 migration

- Add lightweight SchemaMigrationPlan removing needsSync, cloudKitRecordID, isDeleted
- Remove all isDeleted predicates from FetchDescriptors and in-memory filters
- Replace hasInitializedCloudKit UserDefaults with isCloudKitEnabled stored property
- Move StatsView yearlyStats/monthlyStats to @State + .task(id:) for perf
- Remove CloudDocuments from entitlements

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```
