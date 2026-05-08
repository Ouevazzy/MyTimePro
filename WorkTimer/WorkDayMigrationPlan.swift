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
