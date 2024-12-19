import XCTest
import CloudKit
@testable import MyTimePro

class CloudKitManagerTests: XCTestCase {
    var sut: CloudKitManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = CloudKitManager.shared
    }
    
    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }
    
    func testSaveSettings() async throws {
        // Given
        let settings = Settings(
            weeklyHours: 40,
            dailyHours: 8,
            vacationDays: 25,
            workingDays: Set([1, 2, 3, 4, 5])
        )
        
        // When
        try await sut.saveSettings(settings)
        
        // Then
        let savedSettings = try await sut.fetchSettings()
        XCTAssertEqual(savedSettings?.weeklyHours, settings.weeklyHours)
        XCTAssertEqual(savedSettings?.dailyHours, settings.dailyHours)
        XCTAssertEqual(savedSettings?.vacationDays, settings.vacationDays)
        XCTAssertEqual(savedSettings?.workingDays, settings.workingDays)
    }
    
    func testDeleteSettings() async throws {
        // Given
        let settings = Settings(
            weeklyHours: 40,
            dailyHours: 8,
            vacationDays: 25,
            workingDays: Set([1, 2, 3, 4, 5])
        )
        try await sut.saveSettings(settings)
        
        // When
        try await sut.deleteSettings()
        
        // Then
        let savedSettings = try await sut.fetchSettings()
        XCTAssertNil(savedSettings)
    }
}
