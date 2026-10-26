import Foundation
import Testing
@testable import SettleCore

@Suite struct PredictorTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Oslo")!
        return c
    }()

    func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    var predictor: Predictor { Predictor(calendar: calendar) }

    /// A 7-month-old: woke 06:45, napped 09:00–10:15.
    @Test func predictsSecondNapInPlausibleWindow() throws {
        let birth = calendar.date(byAdding: .month, value: -7, to: at(26, 12))!
        let sleeps = [
            SleepRecord(start: at(25, 19), end: at(26, 6, 45)),
            SleepRecord(start: at(26, 9), end: at(26, 10, 15)),
        ]
        let prediction = try predictor.nextSleep(birthDate: birth, sleeps: sleeps, now: at(26, 11))
        #expect(prediction.stage == .established)
        #expect(prediction.earliest <= prediction.target && prediction.target <= prediction.latest)
        let windowHours = prediction.target.timeIntervalSince(at(26, 10, 15)) / 3600
        #expect((1.5...4.0).contains(windowHours), "wake window \(windowHours) h")
    }

    @Test func shortNapPullsNextSleepEarlier() throws {
        let birth = calendar.date(byAdding: .month, value: -7, to: at(26, 12))!
        let night = SleepRecord(start: at(25, 19), end: at(26, 6, 45))
        let shortNap = SleepRecord(start: at(26, 9), end: at(26, 9, 25))
        let longNap = SleepRecord(start: at(26, 9), end: at(26, 10, 30))
        let short = try predictor.nextSleep(birthDate: birth, sleeps: [night, shortNap], now: at(26, 9, 30))
        let long = try predictor.nextSleep(birthDate: birth, sleeps: [night, longNap], now: at(26, 10, 35))
        let shortWindow = short.target.timeIntervalSince(at(26, 9, 25))
        let longWindow = long.target.timeIntervalSince(at(26, 10, 30))
        #expect(shortWindow < longWindow)
        #expect(short.reasons.contains(.shortLastSleep(minutes: 25)))
    }

    @Test func newbornStage() throws {
        let birth = calendar.date(byAdding: .day, value: -21, to: at(26, 12))!
        let p = try predictor.nextSleep(birthDate: birth, sleeps: [SleepRecord(start: at(26, 9), end: at(26, 10))], now: at(26, 10, 10))
        #expect(p.stage == .newborn)
        let window = p.target.timeIntervalSince(at(26, 10)) / 3600
        #expect(window < 2, "newborn wake window \(window) h")
    }

    @Test func refusesWhileAsleepOrWithoutHistory() {
        let birth = at(1, 0)
        #expect(throws: PredictionError.currentlyAsleep) {
            try predictor.nextSleep(birthDate: birth, sleeps: [SleepRecord(start: at(26, 9), end: nil)], now: at(26, 10))
        }
        #expect(throws: PredictionError.noCompletedSleep) {
            try predictor.nextSleep(birthDate: birth, sleeps: [], now: at(26, 10))
        }
    }
}
