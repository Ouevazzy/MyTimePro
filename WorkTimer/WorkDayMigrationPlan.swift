import SwiftData
import Foundation

enum WorkDaySchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] = [WorkDay.self]

    @Model
    final class WorkDay {
        // NOTE: cloudKitRecordID / isDeleted / needsSync are retained here on purpose.
        // The current model (V3) still relies on these fields throughout the app
        // (soft-delete filtering, CloudKit sync). Dropping them in V2 would make the
        // lightweight V1→V2→V3 migration reset isDeleted to false and resurrect every
        // soft-deleted work day. Keep the schema field-compatible so both stages stay
        // lossless lightweight migrations.
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
        var typeRawValue: String = WorkDayType.work.rawValue
        var note: String?
        var bonusAmount: Double = 0.0

        init() {}
    }
}

enum WorkDaySchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] = [WorkDay.self]
}

enum WorkDayMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [
        WorkDaySchemaV1.self,
        WorkDaySchemaV2.self,
        WorkDaySchemaV3.self
    ]

    static var stages: [MigrationStage] = [
        migrateV1toV2,
        migrateV2toV3
    ]

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: WorkDaySchemaV1.self,
        toVersion: WorkDaySchemaV2.self
    )

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: WorkDaySchemaV2.self,
        toVersion: WorkDaySchemaV3.self
    )
}
