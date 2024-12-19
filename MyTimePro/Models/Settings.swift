import CloudKit

struct Settings: Codable {
    var weeklyHours: Double
    var dailyHours: Double
    var vacationDays: Double
    var workingDays: Set<Int>
    
    func toDictionary() -> [String: Any] {
        return [
            "weeklyHours": weeklyHours,
            "dailyHours": dailyHours,
            "vacationDays": vacationDays,
            "workingDays": Array(workingDays)
        ]
    }
    
    init(weeklyHours: Double, dailyHours: Double, vacationDays: Double, workingDays: Set<Int>) {
        self.weeklyHours = weeklyHours
        self.dailyHours = dailyHours
        self.vacationDays = vacationDays
        self.workingDays = workingDays
    }
    
    init(record: CKRecord) {
        self.weeklyHours = record["weeklyHours"] as? Double ?? 35
        self.dailyHours = record["dailyHours"] as? Double ?? 7
        self.vacationDays = record["vacationDays"] as? Double ?? 25
        self.workingDays = Set((record["workingDays"] as? [Int]) ?? Array(1...5))
    }
}