import Foundation

/// A sleep bout in clock hours (hours since local midnight of day 0; may exceed 24).
public struct SleepBout: Sendable, Equatable, Codable {
    public var start: Double
    public var end: Double

    public init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }

    public var duration: Double { end - start }
}

/// One point on a pressure trace.
public struct PressureSample: Sendable, Equatable, Codable {
    public var hour: Double
    public var pressure: Double
    public var upper: Double
    public var lower: Double
    public var asleep: Bool
}

/// Summary of one simulated sleep day (04:00 to 04:00).
public struct DaySummary: Sendable, Equatable, Codable {
    public var sleepBouts: Int
    public var totalSleepHours: Double
    /// Nil before the night consolidates (no bout of 5 h or more).
    public var naps: Int?
    public var nightSleepHours: Double?
    public var daySleepHours: Double?
    public var wakeWindows: [Double]
    public var morningWakeHour: Double?
    public var nightSleepStartHour: Double?
}

public struct SimulatedDay: Sendable, Equatable {
    public var ageWeeks: Double
    public var stage: AgeStage
    public var params: SleepPressureParams
    /// Bouts overlapping the displayed day, in hours relative to its midnight (window 4...28).
    public var bouts: [SleepBout]
    public var samples: [PressureSample]
    public var summary: DaySummary
}

/// Free-running simulation of the model: what the baby's days look like with no outside cues.
public enum Simulator {
    public static let displayStart = 4.0
    public static let displayEnd = 28.0

    /// Runs the model for `days` days from a 07:00 wake. Nil if the model gets stuck.
    public static func freeRun(_ p: SleepPressureParams, days: Int = 10, startHour: Double = 7) -> [SleepBout]? {
        var t = startHour
        var s = p.lower(startHour)
        var bouts: [SleepBout] = []
        while t < Double(days) * 24 {
            guard let awake = p.hoursUntilCrossing(from: s, at: t) else { return nil }
            let start = t + awake
            s = p.risen(from: s, hours: awake)
            guard let asleep = p.hoursUntilWake(from: s, at: start) else { return nil }
            t = start + asleep
            s = p.decayed(from: s, hours: asleep)
            bouts.append(SleepBout(start: start, end: t))
            if bouts.count > days * 20 { return nil }
        }
        return bouts
    }

    /// A settled day (day 8 of a 10-day run), shown 04:00 to 04:00 the next morning.
    public static func day(ageWeeks: Double, curve: AgeCurve = .v1, sampleMinutes: Double = 5) -> SimulatedDay? {
        let p = curve.params(ageWeeks: ageWeeks)
        guard let all = freeRun(p) else { return nil }
        let offset = 8 * 24.0
        let shifted = all.map { SleepBout(start: $0.start - offset, end: $0.end - offset) }
        let visible = shifted.filter { $0.end > displayStart && $0.start < displayEnd }
        return SimulatedDay(
            ageWeeks: ageWeeks,
            stage: AgeStage(ageWeeks: ageWeeks),
            params: p,
            bouts: visible,
            samples: trace(p, bouts: shifted, from: displayStart, to: displayEnd, stepMinutes: sampleMinutes),
            summary: summarize(shifted)
        )
    }

    /// The 0–24 month sweep: one summary per week of age.
    public static func sweep(weeks: ClosedRange<Int> = 1...104, curve: AgeCurve = .v1) -> [(ageWeeks: Int, summary: DaySummary)] {
        weeks.compactMap { wk in
            guard let all = freeRun(curve.params(ageWeeks: Double(wk))) else { return nil }
            let offset = 8 * 24.0
            return (wk, summarize(all.map { SleepBout(start: $0.start - offset, end: $0.end - offset) }))
        }
    }

    /// A stretch of time spent entirely awake or entirely asleep, with the pressure at its start.
    struct Segment {
        var start: Double
        var end: Double
        var asleep: Bool
        var pressureAtStart: Double
    }

    /// Replays bouts into segments. Pressure is assumed to sit at the lower threshold
    /// when the first bout ends (a natural waking).
    static func segments(_ p: SleepPressureParams, bouts: [SleepBout]) -> [Segment] {
        let sorted = bouts.sorted { $0.start < $1.start }
        guard let first = sorted.first else { return [] }
        var t = first.end
        var s = p.lower(t)
        var out: [Segment] = []
        for bout in sorted.dropFirst() where bout.start >= t {
            out.append(Segment(start: t, end: bout.start, asleep: false, pressureAtStart: s))
            s = p.risen(from: s, hours: bout.start - t)
            out.append(Segment(start: bout.start, end: bout.end, asleep: true, pressureAtStart: s))
            s = p.decayed(from: s, hours: bout.duration)
            t = bout.end
        }
        out.append(Segment(start: t, end: .infinity, asleep: false, pressureAtStart: s))
        return out
    }

    /// Samples pressure and thresholds every `stepMinutes` between `from` and `to`
    /// (starting no earlier than the end of the first bout).
    public static func trace(
        _ p: SleepPressureParams,
        bouts: [SleepBout],
        from: Double,
        to: Double,
        stepMinutes: Double = 5
    ) -> [PressureSample] {
        let segs = segments(p, bouts: bouts)
        guard let firstStart = segs.first?.start else { return [] }
        let step = stepMinutes / 60
        var samples: [PressureSample] = []
        var i = 0
        var h = max(from, firstStart)
        while h <= to + 1e-9 {
            while i < segs.count - 1, h >= segs[i].end { i += 1 }
            let seg = segs[i]
            let dt = h - seg.start
            let value = seg.asleep ? p.decayed(from: seg.pressureAtStart, hours: dt) : p.risen(from: seg.pressureAtStart, hours: dt)
            samples.append(PressureSample(hour: h, pressure: value, upper: p.upper(h), lower: p.lower(h), asleep: seg.asleep))
            h += step
        }
        return samples
    }

    /// Summarises the sleep day running 04:00 to 04:00 (hours 4...28).
    public static func summarize(_ bouts: [SleepBout]) -> DaySummary {
        let w0 = displayStart
        let w1 = displayEnd
        let inDay = bouts.filter { $0.start >= w0 && $0.start < w1 }
        let total = bouts.reduce(0.0) { $0 + max(0, min($1.end, w1) - max($1.start, w0)) }
        let night = bouts.filter { $0.start >= 16 && $0.start < w1 && $0.duration >= 5 }.max { $0.duration < $1.duration }
        let previousNight = bouts.filter { $0.start >= -8 && $0.start < w0 && $0.duration >= 5 }.max { $0.duration < $1.duration }
        guard let night, let previousNight else {
            let gaps = zip(bouts, bouts.dropFirst()).filter { $1.start >= w0 && $1.start < w1 }.map { $1.start - $0.end }
            return DaySummary(
                sleepBouts: inDay.count, totalSleepHours: total, naps: nil, nightSleepHours: nil,
                daySleepHours: nil, wakeWindows: gaps, morningWakeHour: nil, nightSleepStartHour: nil
            )
        }
        let naps = bouts.filter { $0.start >= previousNight.end && $0.start < night.start }
        let sequence = [previousNight] + naps + [night]
        let windows = zip(sequence, sequence.dropFirst()).map { $1.start - $0.end }
        return DaySummary(
            sleepBouts: inDay.count,
            totalSleepHours: total,
            naps: naps.count,
            nightSleepHours: night.duration,
            daySleepHours: naps.reduce(0) { $0 + $1.duration },
            wakeWindows: windows,
            morningWakeHour: previousNight.end,
            nightSleepStartHour: night.start
        )
    }
}
