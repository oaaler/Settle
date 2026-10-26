import Testing
@testable import SettleCore

@Suite struct SimulatorTests {
    @Test func newbornDayIsPolyphasicWithoutNightSleep() throws {
        let day = try #require(Simulator.day(ageWeeks: 3))
        #expect(day.stage == .newborn)
        #expect(day.summary.naps == nil)
        #expect(day.summary.sleepBouts >= 5)
    }

    /// Structure only. Free-running quality (e.g. a late long nap at ~30 wk) is a known calibration
    /// limitation shown as-is in the demo; see docs/research/sleep-science.md §6.
    @Test func sevenMonthOldHasConsolidatedNight() throws {
        let day = try #require(Simulator.day(ageWeeks: 30))
        let naps = try #require(day.summary.naps)
        #expect((2...3).contains(naps))
        let night = try #require(day.summary.nightSleepHours)
        #expect(night >= 5)
        #expect(day.summary.wakeWindows.count == naps + 1)
    }

    @Test func traceCoversDisplayWindowAndRespectsSleep() throws {
        let day = try #require(Simulator.day(ageWeeks: 30))
        #expect(day.samples.first?.hour == Simulator.displayStart)
        #expect(abs((day.samples.last?.hour ?? 0) - Simulator.displayEnd) < 0.1)
        for sample in day.samples {
            #expect((0...1).contains(sample.pressure))
            let inBout = day.bouts.contains { $0.start <= sample.hour && sample.hour < $0.end }
            #expect(sample.asleep == inBout, "hour \(sample.hour)")
        }
    }

    @Test func napsDecreaseAcrossTheSweep() {
        let sweep = Simulator.sweep(weeks: 16...104)
        #expect(sweep.count > 80)
        let early = sweep.prefix(4).compactMap(\.summary.naps).max() ?? 0
        let late = sweep.suffix(4).compactMap(\.summary.naps).min() ?? 99
        #expect(early > late)
    }
}
