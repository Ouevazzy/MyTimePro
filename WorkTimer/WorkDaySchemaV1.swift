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

        init() {}
    }
}
