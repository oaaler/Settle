import Foundation
import Testing
@testable import SettleCore

@Suite struct SleepPressureModelTests {
    @Test func closedFormWithoutCircadian() throws {
        // No circadian term: wake window = tauW * ln((1 - S0) / (1 - H)).
        let p = SleepPressureParams(tauW: 2, tauS: 4, h0: 0.6, gap: 0.1, amplitude: 0, phiHour: 18)
        let t = try #require(p.hoursUntilCrossing(from: 0.2, at: 9))
        #expect(abs(t - 2 * log(0.8 / 0.4)) < 1e-4)
    }

    @Test func shortNapGivesShorterWakeWindow() throws {
        let p = AgeCurve.v1.params(ageWeeks: 30)
        let afterShortNap = p.decayed(from: p.upper(11), hours: 0.5)
        let afterLongNap = p.decayed(from: p.upper(11), hours: 1.5)
        let short = try #require(p.hoursUntilCrossing(from: afterShortNap, at: 11.5))
        let long = try #require(p.hoursUntilCrossing(from: afterLongNap, at: 12.5))
        #expect(short < long)
    }

    @Test func pressureBuildsMoreSlowlyWithAge() {
        let c = AgeCurve.v1
        #expect(c.params(ageWeeks: 4).tauW < c.params(ageWeeks: 26).tauW)
        #expect(c.params(ageWeeks: 26).tauW < c.params(ageWeeks: 90).tauW)
    }

    @Test func circadianRampsBetweenEightAndSixteenWeeks() {
        #expect(AgeCurve.circadianRamp(ageWeeks: 4) == 0)
        #expect(AgeCurve.circadianRamp(ageWeeks: 12) == 0.5)
        #expect(AgeCurve.circadianRamp(ageWeeks: 40) == 1)
    }

    /// Parity with tools/calibrate/model.py (1-minute grid there, bisection here).
    @Test func matchesPythonReference() throws {
        let url = try #require(Bundle.module.url(forResource: "reference", withExtension: "json", subdirectory: "Fixtures"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        #expect(fixture.cases.count >= 32)
        for c in fixture.cases {
            let swift = try #require(c.params.hoursUntilCrossing(from: c.s0, at: c.clock_hour))
            // Python reports the first whole minute at/after the crossing.
            #expect(swift <= c.hours_until_sleep + 1e-9, "age \(c.age_weeks) clock \(c.clock_hour)")
            #expect(c.hours_until_sleep - swift < 1.0 / 60 + 1e-9, "age \(c.age_weeks) clock \(c.clock_hour)")
        }
        // The curve in Swift must be the one the fixtures were generated from.
        let curve = AgeCurve.v1
        for c in fixture.cases {
            let p = curve.params(ageWeeks: c.age_weeks)
            #expect(abs(p.tauW - c.params.tauW) < 1e-9)
            #expect(abs(p.amplitude - c.params.amplitude) < 1e-9)
        }
    }

    private struct Fixture: Decodable {
        struct Case: Decodable {
            let age_weeks: Double
            let params: SleepPressureParams
            let clock_hour: Double
            let s0: Double
            let hours_until_sleep: Double
        }
        let cases: [Case]
    }
}
