import Foundation
import SwiftData
import Testing
@testable import WorkTimer

@Suite("Raccourcis Siri")
@MainActor
struct SiriShortcutsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test("Les choix de type de journée couvrent les valeurs utiles du modèle")
    func workDayTypeIntentValuesCoverModelTypes() {
        let rawValues = Set(WorkDayTypeIntentValue.allCases.map(\.workDayType.rawValue))

        #expect(rawValues.contains(WorkDayType.work.rawValue))
        #expect(rawValues.contains(WorkDayType.vacation.rawValue))
        #expect(rawValues.contains(WorkDayType.halfDayVacation.rawValue))
        #expect(!rawValues.contains("work"))
        #expect(!rawValues.contains("vacation"))
    }

    @Test("Chaque choix AppEnum a une représentation visible")
    func workDayTypeIntentValuesHaveDisplayRepresentations() {
        for value in WorkDayTypeIntentValue.allCases {
            #expect(WorkDayTypeIntentValue.caseDisplayRepresentations[value] != nil)
        }
    }

    @Test("Chaque destination WorkTimer exposée à Raccourcis a une représentation visible")
    func workTimerDestinationsHaveDisplayRepresentations() {
        for value in WorkTimerDestinationIntentValue.allCases {
            #expect(WorkTimerDestinationIntentValue.caseDisplayRepresentations[value] != nil)
            #expect(!value.localizedName.isEmpty)
        }
    }

    @Test("Chaque preset de date Siri a une représentation visible")
    func calendarDatePresetsHaveDisplayRepresentations() {
        for value in CalendarDatePresetIntentValue.allCases {
            #expect(CalendarDatePresetIntentValue.caseDisplayRepresentations[value] != nil)
            #expect(!value.localizedName.isEmpty)
        }
    }

    @Test("L'app utilise App Intents sans déclaration SiriKit legacy")
    func appIntentsDoNotDeclareLegacySiriKitIntents() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "INIntentsSupported") == nil)
    }

    @Test("Les descriptions App Intent évitent le mot refusé par App Store Connect")
    func appIntentDescriptionsAvoidRejectedAssistantName() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("WorkTimer/SiriShortcuts.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let descriptionLines = source
            .split(separator: "\n")
            .filter { $0.contains("IntentDescription(") }

        #expect(!descriptionLines.isEmpty)

        for line in descriptionLines {
            #expect(String(line).range(of: "siri", options: .caseInsensitive) == nil)
        }
    }

    @Test("L'ajout rapide conserve le type choisi dans Raccourcis")
    func quickAddKeepsSelectedWorkDayType() {
        clearQuickAddDefaults()
        defer { clearQuickAddDefaults() }

        UserDefaults.standard.set(WorkDayType.vacation.rawValue, forKey: "siri_quick_add_type")
        UserDefaults.standard.set(true, forKey: "siri_should_quick_add")

        guard case .quickAdd(let type) = SiriShortcutsHelper.shared.checkSiriActions() else {
            Issue.record("L'action Siri attendue n'a pas été retournée")
            return
        }

        #expect(type == .vacation)
    }

    @Test("L'ouverture par Raccourcis conserve la destination choisie")
    func openDestinationKeepsSelectedDestination() {
        clearOpenDestinationDefaults()
        defer { clearOpenDestinationDefaults() }

        UserDefaults.standard.set(WorkTimerDestinationIntentValue.stats.rawValue, forKey: "siri_open_destination")
        UserDefaults.standard.set(true, forKey: "siri_should_open_destination")

        guard case .openDestination(let destination) = SiriShortcutsHelper.shared.checkSiriActions() else {
            Issue.record("L'action d'ouverture attendue n'a pas été retournée")
            return
        }

        #expect(destination == .stats)
    }

    @Test("L'ouverture d'une date par Raccourcis conserve la date choisie")
    func openCalendarDateKeepsSelectedDate() {
        clearOpenCalendarDateDefaults()
        defer { clearOpenCalendarDateDefaults() }

        let date = makeDate(year: 2026, month: 6, day: 12, hour: 9, minute: 30)
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: "siri_open_calendar_date")
        UserDefaults.standard.set(true, forKey: "siri_should_open_calendar_date")

        guard case .openCalendarDate(let selectedDate) = SiriShortcutsHelper.shared.checkSiriActions() else {
            Issue.record("L'action d'ouverture de date attendue n'a pas été retournée")
            return
        }

        #expect(selectedDate.timeIntervalSince1970 == date.timeIntervalSince1970)
        #expect(!UserDefaults.standard.bool(forKey: "siri_should_open_calendar_date"))
    }

    @Test("Les presets de date Siri calculent le bon jour")
    func calendarDatePresetsResolveExpectedDates() {
        let today = makeDate(year: 2026, month: 6, day: 12, hour: 15, minute: 45)

        #expect(calendar.isDate(CalendarDatePresetIntentValue.today.date(relativeTo: today, calendar: calendar),
                                inSameDayAs: makeDate(year: 2026, month: 6, day: 12)))
        #expect(calendar.isDate(CalendarDatePresetIntentValue.tomorrow.date(relativeTo: today, calendar: calendar),
                                inSameDayAs: makeDate(year: 2026, month: 6, day: 13)))
        #expect(calendar.isDate(CalendarDatePresetIntentValue.yesterday.date(relativeTo: today, calendar: calendar),
                                inSameDayAs: makeDate(year: 2026, month: 6, day: 11)))
    }

    @Test("Les paramètres App Shortcuts sont rafraîchis seulement quand la signature change")
    func appShortcutParameterRefreshIsSignatureBased() {
        let key = "siri_app_shortcuts_parameter_refresh_signature"
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        var refreshCount = 0
        let firstRefresh = SiriShortcutsHelper.shared.refreshAppShortcutParametersIfNeeded(signature: "shortcuts-v1") {
            refreshCount += 1
        }
        let skippedRefresh = SiriShortcutsHelper.shared.refreshAppShortcutParametersIfNeeded(signature: "shortcuts-v1") {
            refreshCount += 1
        }
        let secondRefresh = SiriShortcutsHelper.shared.refreshAppShortcutParametersIfNeeded(signature: "shortcuts-v2") {
            refreshCount += 1
        }

        #expect(firstRefresh)
        #expect(!skippedRefresh)
        #expect(secondRefresh)
        #expect(refreshCount == 2)
    }

    @Test("Une destination Raccourcis inconnue ouvre le calendrier par défaut")
    func openDestinationFallsBackToCalendar() {
        clearOpenDestinationDefaults()
        defer { clearOpenDestinationDefaults() }

        UserDefaults.standard.set("unknown", forKey: "siri_open_destination")
        UserDefaults.standard.set(true, forKey: "siri_should_open_destination")

        guard case .openDestination(let destination) = SiriShortcutsHelper.shared.checkSiriActions() else {
            Issue.record("L'action d'ouverture attendue n'a pas été retournée")
            return
        }

        #expect(destination == .calendar)
    }

    @Test("L'action arrivée Siri crée une journée de travail en attente")
    func siriArrivalCreatesPendingWorkDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let arrival = makeDate(year: 2026, month: 5, day: 18, hour: 8, minute: 15)

        try SiriActionProcessor(modelContext: context, calendar: calendar).process(.createEntry(arrivalTime: arrival))

        let workDay = try #require(try context.fetch(FetchDescriptor<WorkDay>()).first)
        #expect(calendar.isDate(workDay.date, inSameDayAs: arrival))
        #expect(workDay.type == .work)
        #expect(workDay.startTime == arrival)
        #expect(workDay.endTime == nil)
        #expect(workDay.needsSync)
    }

    @Test("L'action départ Siri complète une journée de travail")
    func siriDepartureCompletesWorkDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let departure = makeDate(year: 2026, month: 5, day: 18, hour: 17, minute: 30)

        try SiriActionProcessor(modelContext: context, calendar: calendar).process(.updateEntry(departureTime: departure))

        let workDay = try #require(try context.fetch(FetchDescriptor<WorkDay>()).first)
        #expect(calendar.isDate(workDay.date, inSameDayAs: departure))
        #expect(workDay.type == .work)
        #expect(workDay.endTime == departure)
        #expect(workDay.totalHours > 0)
    }

    @Test("L'action ajout rapide crée le type demandé")
    func siriQuickAddCreatesSelectedType() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try SiriActionProcessor(modelContext: context, calendar: calendar).process(.quickAdd(type: .sickLeave))

        let workDay = try #require(try context.fetch(FetchDescriptor<WorkDay>()).first)
        #expect(workDay.type == .sickLeave)
        #expect(workDay.startTime == nil)
        #expect(workDay.endTime == nil)
    }

    @Test("Le résumé Siri reflète les données SwiftData récentes")
    func siriSummarySnapshotUsesCurrentWorkDays() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let workDay = makeWorkDay(year: 2026, month: 5, day: 18, startHour: 8, endHour: 17, breakSeconds: 3600)
        let vacationDay = WorkDay(date: makeDate(year: 2026, month: 5, day: 19), type: .vacation)

        context.insert(workDay)
        context.insert(vacationDay)
        try context.save()

        let service = SiriSummaryCacheService(calendar: calendar, now: makeDate(year: 2026, month: 5, day: 20, hour: 12, minute: 0))
        let snapshot = try service.snapshot(using: context)
        let expectedVacationBalance = VacationCalculations.remainingStats(
            for: 2026,
            workDays: [vacationDay],
            annualEntitlement: Double(UserSettings.shared.annualVacationDays)
        ).remaining

        #expect(snapshot.weeklyHours == workDay.totalHours)
        #expect(snapshot.overtimeSeconds == workDay.overtimeSeconds)
        #expect(snapshot.vacationBalance == expectedVacationBalance)
    }

    @Test("Le résumé hebdomadaire Siri inclut les jours de la semaine qui traversent une année")
    func siriWeeklySummaryIncludesCrossYearWeekDays() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let previousYearDay = makeWorkDay(year: 2026, month: 12, day: 31, startHour: 8, endHour: 10, breakSeconds: 0)
        let currentYearDay = makeWorkDay(year: 2027, month: 1, day: 1, startHour: 8, endHour: 11, breakSeconds: 0)

        context.insert(previousYearDay)
        context.insert(currentYearDay)
        try context.save()

        let service = SiriSummaryCacheService(calendar: calendar, now: makeDate(year: 2027, month: 1, day: 1, hour: 12, minute: 0))
        let snapshot = try service.snapshot(using: context)

        #expect(snapshot.weeklyHours == previousYearDay.totalHours + currentYearDay.totalHours)
        #expect(snapshot.overtimeSeconds == currentYearDay.overtimeSeconds)
    }

    @Test("Le rafraîchissement du résumé Siri écrit le cache utilisé hors app")
    func siriSummaryRefreshWritesUserDefaultsCache() throws {
        clearSiriSummaryDefaults()
        defer { clearSiriSummaryDefaults() }

        let container = try makeContainer()
        let context = container.mainContext
        let workDay = makeWorkDay(year: 2026, month: 5, day: 18, startHour: 8, endHour: 17, breakSeconds: 3600)
        context.insert(workDay)
        try context.save()

        let service = SiriSummaryCacheService(calendar: calendar, now: makeDate(year: 2026, month: 5, day: 20, hour: 12, minute: 0))
        let snapshot = try service.snapshot(using: context)
        service.refresh(using: context)

        #expect(UserDefaults.standard.integer(forKey: "cached_overtime_seconds") == snapshot.overtimeSeconds)
        #expect(UserDefaults.standard.double(forKey: "cached_weekly_hours") == snapshot.weeklyHours)
        #expect(UserDefaults.standard.double(forKey: "cached_vacation_balance") >= 0)
    }

    @Test("Les raccourcis de consultation préfèrent un résumé frais au cache vide")
    func siriSummaryProviderPrefersFreshSnapshotOverEmptyCache() {
        clearSiriSummaryDefaults()
        defer {
            SiriSummaryProvider.snapshotOverride = nil
            clearSiriSummaryDefaults()
        }

        let freshSnapshot = SiriSummarySnapshot(
            overtimeSeconds: 3_600,
            vacationBalance: 12.5,
            weeklyHours: 38.25
        )
        SiriSummaryProvider.snapshotOverride = { freshSnapshot }

        let snapshot = SiriSummaryProvider.currentSnapshot()

        #expect(snapshot == freshSnapshot)
        #expect(SiriShortcutsHelper.shared.cachedSummarySnapshot() == freshSnapshot)
    }

    private func clearQuickAddDefaults() {
        UserDefaults.standard.removeObject(forKey: "siri_quick_add_type")
        UserDefaults.standard.removeObject(forKey: "siri_should_quick_add")
    }

    private func clearOpenDestinationDefaults() {
        UserDefaults.standard.removeObject(forKey: "siri_open_destination")
        UserDefaults.standard.removeObject(forKey: "siri_should_open_destination")
    }

    private func clearOpenCalendarDateDefaults() {
        UserDefaults.standard.removeObject(forKey: "siri_open_calendar_date")
        UserDefaults.standard.removeObject(forKey: "siri_should_open_calendar_date")
    }

    private func clearSiriSummaryDefaults() {
        UserDefaults.standard.removeObject(forKey: "cached_overtime_seconds")
        UserDefaults.standard.removeObject(forKey: "cached_vacation_balance")
        UserDefaults.standard.removeObject(forKey: "cached_weekly_hours")
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WorkDay.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    private func makeWorkDay(
        year: Int,
        month: Int,
        day: Int,
        startHour: Int,
        endHour: Int,
        breakSeconds: TimeInterval
    ) -> WorkDay {
        let date = makeDate(year: year, month: month, day: day)
        let workDay = WorkDay(date: date, type: .work)
        workDay.updateData(
            startTime: makeDate(year: year, month: month, day: day, hour: startHour, minute: 0),
            endTime: makeDate(year: year, month: month, day: day, hour: endHour, minute: 0),
            breakDuration: breakSeconds
        )
        return workDay
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }
}
