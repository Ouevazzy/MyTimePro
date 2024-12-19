import Foundation
import SwiftData
import CloudKit
import SwiftUI

class MigrationService: ObservableObject {
    static let shared = MigrationService()
    
    @Published private(set) var migrationStatus: MigrationStatus = .notStarted
    @Published private(set) var progress: Double = 0
    @Published private(set) var error: Error?
    
    private let modelContainer: ModelContainer
    private let cloudService = CloudService.shared
    private let migrationKey = "MyTimePro.hasMigratedToCloudKit"
    
    enum MigrationStatus {
        case notStarted
        case inProgress
        case completed
        case failed(Error)
        
        var description: String {
            switch self {
            case .notStarted: return "Migration non démarrée"
            case .inProgress: return "Migration en cours..."
            case .completed: return "Migration terminée"
            case .failed(let error): return "Échec de la migration: \(error.localizedDescription)"
            }
        }
    }
    
    private init() {
        do {
            let schema = Schema([WorkDay.self])
            let config = ModelConfiguration(schema: schema)
            modelContainer = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Échec de l'initialisation du ModelContainer: \(error)")
        }
    }
    
    func needsMigration() -> Bool {
        !UserDefaults.standard.bool(forKey: migrationKey)
    }
    
    func startMigration() async {
        guard needsMigration() else {
            await updateStatus(.completed)
            return
        }
        
        await updateStatus(.inProgress)
        
        do {
            let descriptor = FetchDescriptor<WorkDay>()
            let workDays = try modelContainer.mainContext.fetch(descriptor)
            let total = Double(workDays.count)
            
            for (index, workDay) in workDays.enumerated() {
                let progress = Double(index) / total
                await updateProgress(progress)
                
                // Création du record CloudKit
                let record = CKRecord(recordType: "WorkDay", recordID: CKRecord.ID(recordName: workDay.id.uuidString))
                record["date"] = workDay.date as CKRecordValue
                record["typeRawValue"] = workDay.typeRawValue as CKRecordValue
                if let startTime = workDay.startTime {
                    record["startTime"] = startTime as CKRecordValue
                }
                if let endTime = workDay.endTime {
                    record["endTime"] = endTime as CKRecordValue
                }
                record["breakDuration"] = workDay.breakDuration as CKRecordValue
                record["totalHours"] = workDay.totalHours as CKRecordValue
                record["overtimeSeconds"] = workDay.overtimeSeconds as CKRecordValue
                if let note = workDay.note {
                    record["note"] = note as CKRecordValue
                }
                record["bonusAmount"] = workDay.bonusAmount as C