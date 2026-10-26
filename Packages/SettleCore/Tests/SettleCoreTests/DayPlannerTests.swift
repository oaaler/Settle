import Testing
@testable import SettleCore

@Suite struct DayPlannerTests {
    let planner = DayPlanner()

    @Test func planEndsInNightSleepWithNapsBeforeIt() throws {
        let plan = try planner.plan(ageWeeks: 30, morningWake: 6.75, naps: [LoggedNap(start: 9, end: 10.25)], now: 11)
        #expect(!plan.asleepNow)
        let window = try #require(plan.sleepWindow)
        #expect(window.earliest <= window.target && window.target <= window.latest)
        #expect(plan.plan.last?.kind == .night)
        #expect(plan.plan.dropLast().allSatisfy { $0.kind == .nap && $0.end != nil })
        // Planned sleeps are in order and start after now.
        let starts = plan.plan.map(\.start)
        #expect(starts == starts.sorted())
        #expect(starts.allSatisfy { $0 > 11 })
    }

    @Test func sleepWindowMatchesFirstPlannedSleep() throws {
        let plan = try planner.plan(ageWeeks: 30, morningWake: 7, naps: [], now: 8)
        let window = try #require(plan.sleepWindow)
        let first = try #require(plan.plan.first)
        #expect(abs(window.target - first.start) < 1e-6)
    }

    @Test func ongoingNapGetsPredictedEnd() throws {
        let plan = try planner.plan(ageWeeks: 30, morningWake: 7, naps: [LoggedNap(start: 9.5, end: nil)], now: 10)
        #expect(plan.asleepNow)
        #expect(plan.sleepWindow == nil)
        let current = try #require(plan.plan.first)
        #expect(current.inProgress)
        #expect(current.start == 9.5)
        #expect(try #require(current.end) > 10)
    }

    @Test func samplesRunFromMorningWakePastBedtime() throws {
        let plan = try planner.plan(ageWeeks: 43, morningWake: 6.5, naps: [LoggedNap(start: 9, end: 10)], now: 12)
        let nightStart = try #require(plan.plan.last?.start)
        #expect(plan.samples.first?.hour == 6.5)
        #expect((plan.samples.last?.hour ?? 0) >= nightStart + 0.9)
        #expect(plan.samples.contains { $0.asleep && $0.hour > nightStart })
    }

    @Test func pressureAgreesWithDatePredictor() throws {
        // DayPlanner (clock hours) and Predictor (Dates) must tell the same story.
        let plan = try planner.plan(ageWeeks: 30, morningWake: 7, naps: [LoggedNap(start: 9, end: 10)], now: 11)
        let p = AgeCurve.v1.params(ageWeeks: 30)
        var s = p.lower(7)
        s = p.risen(from: s, hours: 2)
        s = p.decayed(from: s, hours: 1)
        s = p.risen(from: s, hours: 1)
        #expect(abs(plan.pressureNow - s) < 1e-9)
    }

    @Test func rejectsInvalidInput() {
        #expect(throws: DayPlanError.nowBeforeMorningWake) {
            try planner.plan(ageWeeks: 30, morningWake: 7, naps: [], now: 6)
        }
        #expect(throws: DayPlanError.napsOverlapOrUnordered) {
            try planner.plan(ageWeeks: 30, morningWake: 7, naps: [LoggedNap(start: 9, end: 10), LoggedNap(start: 9.5, end: 11)], now: 12)
        }
        #expect(throws: DayPlanError.napInFuture) {
            try planner.plan(ageWeeks: 30, morningWake: 7, naps: [LoggedNap(start: 9, end: 13)], now: 12)
        }
        #expect(throws: DayPlanError.onlyLastNapMayBeOngoing) {
            try planner.plan(ageWeeks: 30, morningWake: 7, naps: [LoggedNap(start: 9, end: nil), LoggedNap(start: 10, end: 11)], now: 12)
        }
    }
}
