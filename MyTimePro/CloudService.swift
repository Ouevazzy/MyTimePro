import Foundation
import CloudKit
import SwiftData

@MainActor
class CloudService: ObservableObject {
    static let shared = CloudService()
    private let container: CKContainer
    private let database: CKDatabase
    
    @Published var isCloudAvailable = false
    @Published var isSignedInToiCloud = false
    
    private init() {
        container = CKContainer(identifier: "iCloud.jordan-payez.MyTimePro")
        database = container.privateCloudDatabase
        Task {
            await checkCloudStatus()
        }
    }
    
    func checkCloudStatus() async {
        do {
            let status = try await container.accountStatus()
            isSignedInToiCloud = status == .available
            isCloudAvailable = status == .available
        } catch {
            print("Erreur lors de la vérification du statut iCloud: \(error)")
            isSignedInToiCloud = false
            isCloudAvailable = false
        }
    }
    
    func saveWorkDay(_ workDay: WorkDay) async throws {
        guard isCloudAvailable else { throw CloudError.cloudNotAvailable }
        
        let record = CKRecord(recordType: "WorkDay")
        record.setValue(workDay.id, forKey: "id")
        record.setValue(workDay.date, forKey: "date")
        record.setValue(workDay.startTime, forKey: "startTime")
        record.setValue(workDay.endTime, forKey: "endTime")
        record.setValue(workDay.pauseDuration, forKey: "pauseDuration")
        record.setValue(workDay.totalDuration, forKey: "totalDuration")
        record.setValue(workDay.isVacation, forKey: "isVacation")
        record.setValue(workDay.vacationType?.rawValue, forKey: "vacationType")
        
        _ = try await database.save(record)
    }
    
    func fetchWorkDays() async throws -> [WorkDay] {
        guard isCloudAvailable else { throw CloudError.cloudNotAvailable }
        
        let query = CKQuery(recordType: "WorkDay", predicate: NSPredicate(value: true))
        let records = try await database.records(matching: query)
        
        return try records.matchResults.compactMap { try? $0.1.get() }.map { record in
            WorkDay(
                id: record.value(forKey: "id") as? UUID ?? UUID(),
                date: record.value(forKey: "date") as? Date ?? Date(),
                startTime: record.value(forKey: "startTime") as? Date ?? Date(),
                endTime: record.value(forKey: "endTime") as? Date ?? Date(),
                pauseDuration: record.value(forKey: "pauseDuration") as? TimeInterval ?? 0,
                totalDuration: record.value(forKey: "totalDuration") as? TimeInterval ?? 0,
                isVacation: record.value(forKey: "isVacation") as? Bool ?? false,
                vacationType: VacationType(rawValue: record.value(forKey: "vacationType") as? String ?? "")
            )
        }
    }
    
    func deleteWorkDay(_ workDay: WorkDay) async throws {
        guard isCloudAvailable else { throw CloudError.cloudNotAvailable }
        
        let recordID = CKRecord.ID(recordName: workDay.id.uuidString)
        try await database.deleteRecord(withID: recordID)
    }
    
    func syncWithCloud(context: ModelContext) async throws {
        guard isCloudAvailable else { throw CloudError.cloudNotAvailable }
        
        // Récupérer les données du cloud
        let cloudWorkDays = try await fetchWorkDays()
        
        // Récupérer les données locales
        let descriptor = FetchDescriptor<WorkDay>()
        let localWorkDays = try context.fetch(descriptor)
        
        // Créer des dictionnaires pour faciliter la comparaison
        let cloudDict = Dictionary(uniqueKeysWithValues: cloudWorkDays.map { ($0.id, $0) })
        let localDict = Dictionary(uniqueKeysWithValues: localWorkDays.map { ($0.id, $0) })
        
        // Ajouter ou mettre à jour les entrées du cloud
        for cloudWorkDay in cloudWorkDays {
            if let localWorkDay = localDict[cloudWorkDay.id] {
                // Mettre à jour l'entrée locale si nécessaire
                localWorkDay.update(from: cloudWorkDay)
            } else {
                // Ajouter une nouvelle entrée
                context.insert(cloudWorkDay)
            }
        }
        
        // Ajouter au cloud les entrées locales manquantes
        for localWorkDay in localWorkDays {
            if cloudDict[localWorkDay.id] == nil {
                try await saveWorkDay(localWorkDay)
            }
        }
        
        try context.save()
    }
}

enum CloudError: Error {
    case cloudNotAvailable
    case saveFailed
    case fetchFailed
    case deleteFailed
}
