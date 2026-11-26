//
//  TimerWidgetTests.swift
//  WorkTimerTests
//
//  Commandes du widget « Chrono » et du Centre de contrôle, et état partagé.
//

import Testing
import Foundation
import SwiftData
@testable import WorkTimer

@Suite("Widget Chrono — commandes", .serialized)
@MainActor
struct TimerWidgetTests {
    private let calendar = Calendar.current

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        let day = calendar.date(from: DateComponents(year: 2026, month: 3, day: 11))!
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([WorkDay.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    @Test("Arrivée, pause, reprise et départ enregistrent la journée et vident l'état partagé")
    func fullSession() throws {
        let timer = TimerManager.shared
        timer.reset()
        let container = try makeContainer()

        TimerIntentHandler.perform(.start, timer: timer, container: container, at: at(8))
        #expect(SharedTimerState.read().startDate == at(8))

        TimerIntentHandler.perform(.pause, timer: timer, container: container, at: at(12))
        #expect(SharedTimerState.read().isPaused)

        TimerIntentHandler.perform(.resume, timer: timer, container: container, at: at(13))
        #expect(!SharedTimerState.read().isPaused)
        #expect(SharedTimerState.read().pausedAccumulated == 3600)

        TimerIntentHandler.perform(.stop, timer: timer, container: container, at: at(17))
        let days = try container.mainContext.fetch(FetchDescriptor<WorkDay>())
        #expect(days.count == 1)
        #expect(abs((days.first?.totalHours ?? 0) - 8) < 0.01)
        #expect(!timer.isActive)
        #expect(!SharedTimerState.read().isActive)
    }

    @Test("Départ sans session : rien n'est créé")
    func stopWithoutSession() throws {
        let timer = TimerManager.shared
        timer.reset()
        let container = try makeContainer()
        TimerIntentHandler.perform(.stop, timer: timer, container: container, at: at(17))
        #expect(try container.mainContext.fetch(FetchDescriptor<WorkDay>()).isEmpty)
    }

    @Test("État partagé : aller-retour et compteur")
    func sharedStateRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("timer-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(!SharedTimerState.read(from: url).isActive)

        let running = SharedTimerState(startDate: at(8), pausedAccumulated: 1800)
        running.write(to: url)
        #expect(SharedTimerState.read(from: url) == running)
        #expect(running.countingStart == at(8, 30))
        #expect(running.workedSeconds(at: at(10)) == 5400)

        let paused = SharedTimerState(startDate: at(8), pausedAccumulated: 0, pauseStartedAt: at(9))
        #expect(paused.countingStart == nil)
        #expect(paused.workedSeconds(at: at(10)) == 3600)

        SharedTimerState().write(to: url)
        #expect(!SharedTimerState.read(from: url).isActive)
    }
}
