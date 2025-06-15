import Foundation
import CloudKit
import SwiftUI
import SwiftData

// Une classe simple pour gérer les opérations CloudKit
final class CloudService {
    // Singleton
    static let shared = CloudService()
    
    private init() {}
    
    // Méthode pour supprimer un record CloudKit par ID
    func deleteRecord(withID recordID: String) async {
        guard let ckRecordID = convertToRecordID(recordID) else {
            print("❌ Impossible de convertir l'ID de record: \(recordID)")
            return
        }
        
        do {
            let container = CKContainer(identifier: "iCloud.jordan-payez.MyTimePro")
            let database = container.privateCloudDatabase
            try await database.deleteRecord(withID: ckRecordID)
            print("✅ Record supprimé avec succès: \(recordID)")
        } catch {
            print("❌ Erreur lors de la suppression du record: \(error.localizedDescription)")
        }
    }
    
    // Convertit une chaîne de caractères en CKRecord.ID
    private func convertToRecordID(_ recordIDString: String) -> CKRecord.ID? {
        // Format attendu: "recordName:zoneID:ownerName"
        let components = recordIDString.components(separatedBy: ":")
        
        if components.count >= 3 {
            let recordName = components[0]
            let zoneName = components[1]
            let ownerName = components[2]
            
            let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName)
            return CKRecord.ID(recordName: recordName, zoneID: zoneID)
        }
        
        // Si le format est simplement un recordName
        if components.count == 1 {
            // Utiliser la zone par défaut
            let zoneID = CKRecordZone.ID(zoneName: "MyTimeProZone", ownerName: CKCurrentUserDefaultName)
            return CKRecord.ID(recordName: recordIDString, zoneID: zoneID)
        }
        
        return nil
    }
} 