import Foundation
import SwiftData

struct SiriSummarySnapshot: Equatable {
    let overtimeSeconds: Int
    let vacationBalance: Double
    let weeklyHours: Double
}

@MainActor
enum SiriSummaryProvider {
    static var snapshotOverride: (() throws -> SiriSummarySnapshot)?

    static func currentSnapshot() -> SiriSummarySnapshot {
        if let snapshotOverride {
            do {
                let snapshot = try snapshotOverride()
                SiriShortcutsHelper.shared.updateCachedData(snapshot)
                return snapshot
            } catch {
                AppLogger.error("Siri summary override failed", category: AppLogger.data, error: error)
            }
        }

        do {
            let snapshot = try SiriSummaryCacheService().snapshotFromPersistentStore()
            SiriShortcutsHelper.shared.updateCachedData(snapshot)
            return snapshot
        } catch {
            AppLogger.error("Siri direct summary read failed; using cached values", category: AppLogger.data, error: error)
            return SiriShortcutsHelper.shared.cachedSummarySnapshot()
        }
    }
}

@MainActor
struct SiriSummaryCacheService {
    private static var persistentContainer: ModelContainer?

    var calendar: Calendar = .current
    var now: Date = Date()
    var settings = UserSettings.shared

    func refresh(using modelContext: ModelContext) {
        do {
            let snapshot = try snapshot(using: modelContext)
            SiriShortcutsHelper.shared.updateCachedData(snapshot)
            // ✅ Publie aussi vers le widget (no-op tant que l'App Group n'est pas configuré)
            WidgetSnapshotService.write(snapshot)
        } catch {
            AppLogger.error("Siri summary cache refresh failed", category: AppLogger.data, error: error)
        }
    }

    func snapshotFromPersistentStore() throws -> SiriSummarySnapshot {
        let container = try Self.modelContainer()
        return try snapshot(using: container.mainContext)
    }

    func snapshot(using modelContext: ModelContext) throws -> SiriSummarySnapshot {
        let currentYear = calendar.component(.year, from: now)
        let yearInterval = try dateInterval(for: DateComponents(year: currentYear), adding: .year)
        let weekComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        let weekInterval = try dateInterval(for: weekComponents, adding: .day, value: 7)
        let fetchStart = min(yearInterval.start, weekInterval.start)
        let fetchEnd = max(yearInterval.end, weekInterval.end)
        let workDays = try fetchWorkDays(from: fetchStart, to: fetchEnd, using: modelContext)

        let yearStats = WorkTimeCalculations.activePeriodStats(
            from: workDays,
            startDate: yearInterval.start,
            endDate: yearInterval.end
        )
        let weekStats = WorkTimeCalculations.activePeriodStats(
            from: workDays,
            startDate: weekInterval.start,
            endDate: weekInterval.end
        )
        let vacationBalance = try currentVacationBalance(currentYear: currentYear, using: modelContext)

        return SiriSummarySnapshot(
            overtimeSeconds: yearStats.overtimeSeconds,
            vacationBalance: vacationBalance,
            weeklyHours: weekStats.totalHours
        )
    }

    private func currentVacationBalance(currentYear: Int, using modelContext: ModelContext) throws -> Double {
        let startYear = calendar.component(.year, from: settings.vacationStartDate)
        let lowerBoundYear = min(startYear, currentYear)
        let startDate = calendar.date(from: DateComponents(year: lowerBoundYear)) ?? Date.distantPast
        let endDate = calendar.date(byAdding: .year, value: 1, to: calendar.date(from: DateComponents(year: currentYear)) ?? now) ?? Date.distantFuture
        let vacation = WorkDayType.vacation.rawValue
        let halfDayVacation = WorkDayType.halfDayVacation.rawValue

        var descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate<WorkDay> { day in
                day.date >= startDate &&
                day.date < endDate &&
                !day.isDeleted &&
                (day.typeRawValue == vacation || day.typeRawValue == halfDayVacation)
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        descriptor.propertiesToFetch = [\.date, \.typeRawValue, \.isDeleted]

        let vacationDays = try modelContext.fetch(descriptor)
        return VacationCalculations.remainingStats(
            for: currentYear,
            workDays: vacationDays,
            annualEntitlement: Double(settings.annualVacationDays)
        ).remaining
    }

    private func fetchWorkDays(from startDate: Date, to endDate: Date, using modelContext: ModelContext) throws -> [WorkDay] {
        var descriptor = FetchDescriptor<WorkDay>(
            predicate: #Predicate<WorkDay> { day in
                day.date >= startDate &&
                day.date < endDate &&
                !day.isDeleted
            }
        )
        descriptor.propertiesToFetch = [
            \.date, \.typeRawValue, \.totalHours,
            \.overtimeSeconds, \.isDeleted
        ]
        return try modelContext.fetch(descriptor)
    }

    private func dateInterval(
        for components: DateComponents,
        adding component: Calendar.Component,
        value: Int = 1
    ) throws -> (start: Date, end: Date) {
        guard let start = calendar.date(from: components),
              let end = calendar.date(byAdding: component, value: value, to: start) else {
            throw SiriSummaryCacheError.invalidDateInterval
        }

        return (start, end)
    }

    private static func modelContainer() throws -> ModelContainer {
        if let persistentContainer {
            return persistentContainer
        }

        do {
            let container = try makeModelContainer(cloudKitEnabled: defaultCloudKitEnabled)
            persistentContainer = container
            return container
        } catch {
            AppLogger.error("Siri persistent ModelContainer failed", category: AppLogger.data, error: error)
            let fallback = try makeModelContainer(cloudKitEnabled: false)
            persistentContainer = fallback
            return fallback
        }
    }

    private static var defaultCloudKitEnabled: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }

    private static func makeModelContainer(cloudKitEnabled: Bool) throws -> ModelContainer {
        let schema = Schema([WorkDay.self])
        let configuration: ModelConfiguration

        if cloudKitEnabled {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .private("iCloud.jordan-payez.MyTimePro")
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                cloudKitDatabase: .none
            )
        }

        return try ModelContainer(
            for: schema,
            migrationPlan: WorkDayMigrationPlan.self,
            configurations: configuration
        )
    }
}

private enum SiriSummaryCacheError: Error {
    case invalidDateInterval
}
