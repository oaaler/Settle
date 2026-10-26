import Foundation

/// A nap logged today, in clock hours. `end == nil` means the baby is asleep now.
public struct LoggedNap: Sendable, Equatable, Codable {
    public var start: Double
    public var end: Double?

    public init(start: Double, end: Double?) {
        self.start = start
        self.end = end
    }
}

public struct SleepWindowHours: Sendable, Equatable, Codable {
    public var earliest: Double
    public var target: Double
    public var latest: Double
}

public struct PlannedSleep: Sendable, Equatable, Codable {
    public enum Kind: String, Sendable, Codable {
        case nap
        case night
    }

    public var kind: Kind
    public var start: Double
    /// Natural end predicted by the model. Nil for night sleep (the plan stops there).
    public var end: Double?
    /// True for the nap in progress at `now`.
    public var inProgress: Bool
}

public struct DayPlan: Sendable, Equatable {
    public var stage: AgeStage
    public var params: SleepPressureParams
    public var pressureNow: Double
    public var asleepNow: Bool
    /// Nil while the baby is asleep.
    public var sleepWindow: SleepWindowHours?
    public var reasons: [PredictionReason]
    /// The rest of today: remaining naps, then the start of night sleep.
    public var plan: [PlannedSleep]
    /// Pressure trace from the morning wake to an hour into night sleep (logged and planned).
    public var samples: [PressureSample]
}

public enum DayPlanError: Error, Equatable {
    case napBeforeMorningWake
    case napsOverlapOrUnordered
    case napInFuture
    case napEndsBeforeStart
    case onlyLastNapMayBeOngoing
    case nowBeforeMorningWake
    case modelStuck
}

/// Plans the rest of a sleep day from the morning wake and today's naps (all in clock hours).
public struct DayPlanner: Sendable {
    public var curve: AgeCurve
    /// Half-width of the sleep window, as an offset on the upper threshold.
    public var windowBand: Double = 0.01
    /// A predicted sleep of at least this many hours is night sleep.
    public var nightMinimumHours: Double = 5
    public var sampleMinutes: Double = 5

    public init(curve: AgeCurve = .v1) {
        self.curve = curve
    }

    public func plan(ageWeeks: Double, morningWake: Double, naps: [LoggedNap], now: Double) throws -> DayPlan {
        try validate(morningWake: morningWake, naps: naps, now: now)
        let p = curve.params(ageWeeks: ageWeeks)

        // Logged history up to now. The night before ends at the morning wake (pressure at the lower threshold).
        var history = [SleepBout(start: morningWake - 10, end: morningWake)]
        history += naps.map { SleepBout(start: $0.start, end: $0.end ?? now) }
        let ongoing = naps.last.map { $0.end == nil } ?? false
        // History ends awake (an ongoing nap is clipped at now), so the final segment holds the current state.
        guard let final = Simulator.segments(p, bouts: history).last else { throw DayPlanError.modelStuck }
        let pressureNow = p.risen(from: final.pressureAtStart, hours: now - final.start)

        // Walk forward from now.
        var plan: [PlannedSleep] = []
        var t = now
        var s = pressureNow
        if ongoing, let napStart = naps.last?.start {
            guard let remaining = p.hoursUntilWake(from: s, at: t) else { throw DayPlanError.modelStuck }
            plan.append(PlannedSleep(kind: .nap, start: napStart, end: t + remaining, inProgress: true))
            s = p.decayed(from: s, hours: remaining)
            t += remaining
        }
        while plan.last?.kind != .night {
            guard let awake = p.hoursUntilCrossing(from: s, at: t) else { throw DayPlanError.modelStuck }
            let start = t + awake
            s = p.risen(from: s, hours: awake)
            guard let asleep = p.hoursUntilWake(from: s, at: start) else { throw DayPlanError.modelStuck }
            // Stop by the next morning even if the model never produces a long sleep.
            let isNight = asleep >= nightMinimumHours || start >= morningWake + 20
            plan.append(PlannedSleep(kind: isNight ? .night : .nap, start: start, end: isNight ? nil : start + asleep, inProgress: false))
            s = p.decayed(from: s, hours: asleep)
            t = start + asleep
        }

        let window: SleepWindowHours? = ongoing ? nil : sleepWindow(p, pressure: pressureNow, now: now)
        let lastCompleted = naps.last { $0.end != nil }.map { ($0.end ?? $0.start) - $0.start }
        let reasons = PredictionReason.explain(params: p, lastSleepHours: lastCompleted, targetHour: window?.target)

        let nightStart = plan.last?.start ?? now
        let plannedBouts = plan.filter { !$0.inProgress }.map { SleepBout(start: $0.start, end: $0.end ?? nightStart + 1) }
        var allBouts = history
        if ongoing, let inProgress = plan.first, let end = inProgress.end {
            allBouts[allBouts.count - 1] = SleepBout(start: inProgress.start, end: end)
        }
        let samples = Simulator.trace(
            p, bouts: allBouts + plannedBouts, from: morningWake, to: nightStart + 1, stepMinutes: sampleMinutes)

        return DayPlan(
            stage: AgeStage(ageWeeks: ageWeeks),
            params: p,
            pressureNow: pressureNow,
            asleepNow: ongoing,
            sleepWindow: window,
            reasons: reasons,
            plan: plan,
            samples: samples
        )
    }

    private func sleepWindow(_ p: SleepPressureParams, pressure: Double, now: Double) -> SleepWindowHours? {
        guard let mid = p.hoursUntilCrossing(from: pressure, at: now) else { return nil }
        let early = p.hoursUntilCrossing(from: pressure, at: now, offset: -windowBand) ?? mid
        let late = p.hoursUntilCrossing(from: pressure, at: now, offset: windowBand) ?? mid
        return SleepWindowHours(earliest: now + early, target: now + mid, latest: now + late)
    }

    private func validate(morningWake: Double, naps: [LoggedNap], now: Double) throws {
        guard now >= morningWake else { throw DayPlanError.nowBeforeMorningWake }
        var cursor = morningWake
        for (i, nap) in naps.enumerated() {
            guard nap.start >= morningWake else { throw DayPlanError.napBeforeMorningWake }
            guard nap.start >= cursor else { throw DayPlanError.napsOverlapOrUnordered }
            guard nap.start <= now else { throw DayPlanError.napInFuture }
            if let end = nap.end {
                guard end > nap.start else { throw DayPlanError.napEndsBeforeStart }
                guard end <= now else { throw DayPlanError.napInFuture }
                cursor = end
            } else {
                guard i == naps.count - 1 else { throw DayPlanError.onlyLastNapMayBeOngoing }
            }
        }
    }
}

extension PredictionReason {
    /// Plain-language reasons for a sleep window: last sleep length and the evening body clock.
    static func explain(params p: SleepPressureParams, lastSleepHours: Double?, targetHour: Double?) -> [PredictionReason] {
        var out: [PredictionReason] = []
        if let hours = lastSleepHours {
            let minutes = Int((hours * 60).rounded())
            if minutes < 40 { out.append(.shortLastSleep(minutes: minutes)) }
            if minutes > 120 && minutes < 300 { out.append(.longLastSleep(minutes: minutes)) }
        }
        if let target = targetHour, p.amplitude > 0 {
            // Thresholds peak at phiHour and then fall, which pulls bedtime in.
            let falling = sin(2 * .pi * (target - p.phiHour) / 24) > 0
            let hour = Int(target.rounded(.down)) % 24
            if falling, (17...23).contains(hour) { out.append(.eveningClock) }
        }
        return out
    }
}
