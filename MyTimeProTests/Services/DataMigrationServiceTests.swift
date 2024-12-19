import XCTest
@testable import MyTimePro

class DataMigrationServiceTests: XCTestCase {
    var sut: DataMigrationService!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = DataMigrationService.shared
    }
    
    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }
    
    func testMigrationFromInitialVersion() async throws {
        // Given
        UserDefaults.standard.set("0.0", forKey: "LastMigrationVersion")
        UserDefaults.standard.set(35.0, forKey: "weeklyHours")
        UserDefaults.standard.set(7.0, forKey: "dailyHours")
        UserDefaults.standard.set(25.0, forKey: "vacationDays")
        UserDefaults.standard.set([1, 2, 3, 4, 5], forKey: "workingDays")
        
        // When
        try await sut.performMigrationIfNeeded()
        
        // Then
        let settings = try await CloudKitManager.shared.fetchSettings()
        XCTAssertNotNil(settings)
        XCTAssertEqual(settings?.weeklyHours, 35.0)
        XCTAssertEqual(settings?.dailyHours, 7.0)
        XCTAssertEqual(settings?.vacationDays, 25.0)
        XCTAssertEqual(settings?.workingDays, Set([1, 2, 3, 4, 5]))
    }
}
