import Foundation

enum ExportType: String, CaseIterable {
    case pdf = "PDF"
    case excel = "Excel"
    
    var displayName: String {
        return rawValue
    }
}
