import SwiftData
import Foundation

enum WorkDaySchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
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
        var typeRawValue: String = WorkDayType.work.rawValue
        var note: String?
        var bonusAmount: Double = 0.0

        init() {}
    }
}

/// The original V2 build (8ee17c0) used a smaller persisted schema.
enum WorkDayCompactSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] = [WorkDay.self]

    @Model final class WorkDay {
        #Index<WorkDay>([\.date], [\.typeRawValue])
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
        var bonusAmount: Double = 0

        init() {}
    }
}

enum WorkDaySchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] = [WorkDay.self]
}

enum WorkDayMigrationPlan: SchemaMigrationPlan {
    // V1 and V2 have the same persisted Core Data model checksum.
    // A single source stage therefore handles stores from either version.
    static var schemas: [any VersionedSchema.Type] = [WorkDayCompactSchemaV2.self, WorkDaySchemaV1.self, WorkDaySchemaV3.self]
    static var stages: [MigrationStage] = [
        // Add the missing fields first. Richer stores skip this stage.
        .lightweight(fromVersion: WorkDayCompactSchemaV2.self, toVersion: WorkDaySchemaV1.self),
        .lightweight(fromVersion: WorkDaySchemaV1.self, toVersion: WorkDaySchemaV3.self)
    ]
}
