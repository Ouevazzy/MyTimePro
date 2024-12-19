import XCTest
@testable import MyTimePro

class StatisticsViewModelTests: XCTestCase {
    var sut: StatisticsViewModel!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = StatisticsViewModel()
    }
    
    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }
    
    func testLoadStatistics() async throws {
        // Given
        let period = StatisticsPeriod.week
        
        // When
        await sut.loadStatistics(for: period)
        
        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.showingError)
        XCTAssertNotNil(sut.chartData)
    }
    
    func testTotalHoursFormatting() {
        // Given
        sut.totalWorkedHours = 35.5
        
        // Then
        XCTAssertEqual(sut.totalHours, "35.5 h")
    }
    
    func testAverageHoursCalculation() {
        // Given
        sut.totalWorkedHours = 35.5
        sut.chartData = [
            ChartDataPoint(date: Date(), hours: 7.5),
            ChartDataPoint(date: Date(), hours: 8.0),
            ChartDataPoint(date: Date(), hours: 7.0),
            ChartDataPoint(date: Date(), hours: 6.5),
            ChartDataPoint(date: Date(), hours: 6.5)
        ]
        
        // Then
        XCTAssertEqual(sut.averageHoursPerDay, "7.1 h")
    }
    
    func testWorkedDaysCount() {
        // Given
        sut.chartData = [
            ChartDataPoint(date: Date(), hours: 7.5),
            ChartDataPoint(date: Date(), hours: 8.0),
            ChartDataPoint(date: Date(), hours: 7.0)
        ]
        
        // Then
        XCTAssertEqual(sut.workedDaysCount, "3 jours")
    }
    
    func testWeekdayDistribution() {
        // Given
        let monday = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let tuesday = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 2))!
        
        sut.weekdayDistribution = [
            2: 8.0,  // Monday
            3: 7.5   // Tuesday
        ]
        
        // Then
        XCTAssertEqual(sut.weekdayDistribution[2], 8.0)
        XCTAssertEqual(sut.weekdayDistribution[3], 7.5)
    }
}