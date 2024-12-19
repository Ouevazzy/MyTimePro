import XCTest
import CloudKit
@testable import MyTimePro

class TimeRecordTests: XCTestCase {
    var sut: TimeRecord!
    let testDate = Date()
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = TimeRecord(
            date: testDate,
            startTime: testDate.addingTimeInterval(-3600), // 1 hour ago
            endTime: testDate
        )
    }
    
    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }
    
    func testTimeRecordInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut.duration, 3600) // 1 hour
    }
    
    func testTimeRecordCloudKitConversion() {
        // When
        let record = sut.toCKRecord()
        let convertedBack = TimeRecord(record: record)
        
        // Then
        XCTAssertNotNil(convertedBack)
        XCTAssertEqual(convertedBack?.id, sut.id)
        XCTAssertEqual(convertedBack?.date.timeIntervalSince1970, sut.date.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(convertedBack?.startTime.timeIntervalSince1970, sut.startTime.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(convertedBack?.endTime.timeIntervalSince1970, sut.endTime.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(convertedBack?.duration, sut.duration)
    }
    
    func testFormattedDuration() {
        XCTAssertEqual(sut.formattedDuration, "1h 00m")
        
        // Test with different duration
        let record = TimeRecord(
            date: testDate,
            startTime: testDate.addingTimeInterval(-5400), // 1.5 hours ago
            endTime: testDate
        )
        XCTAssertEqual(record.formattedDuration, "1h 30m")
    }
    
    func testFormattedDate() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "fr_FR")
        let expectedDate = formatter.string(from: testDate)
        
        XCTAssertEqual(sut.formattedDate, expectedDate)
    }
    
    func testFormattedTimes() {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        
        let expectedStartTime = formatter.string(from: sut.startTime)
        let expectedEndTime = formatter.string(from: sut.endTime)
        
        XCTAssertEqual(sut.formattedStartTime, expectedStartTime)
        XCTAssertEqual(sut.formattedEndTime, expectedEndTime)
    }
}