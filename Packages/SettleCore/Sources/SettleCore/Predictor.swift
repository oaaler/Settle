import Foundation

/// A logged sleep. `end == nil` means the baby is asleep now.
public struct SleepRecord: Sendable, Equatable, Codable {
    public var start: Date
    public var end: Date?

    public init(start: Date, end: Date?) {
        self.start = start
        self.end = end
    }
}

public enum AgeStage: Sendable, Equatable {
    /// 0–8 weeks: no body clock yet; show "time since last sleep" hints only.
    case newborn
    /// 8–16 weeks: body clock emerging.
    case emerging
    /// 16+ weeks: full model.
    case established

    public init(ageWeeks: Double) {
        switch ageWeeks {
        case ..<8: self = .newborn
        case ..<16: self = .emerging
        default: self = .established
        }
    }
}

public enum PredictionReason: Sendable, Equatable {
    case shortLastSleep(minutes: Int)
    case longLastSleep(minutes: Int)
    case eveningClock
}

public struct SleepPrediction: Sendable, Equatable {
    /// Best estimate of when the next sleep window opens.
    public var target: Date
    public var earliest: Date
    public var latest: Date
    /// Current sleep pressure, 0...1.
    public var pressure: Double
    public var stage: AgeStage
    public var reasons: [PredictionReason]
}

public enum PredictionError: Error, Equatable {
    case noCompletedSleep
    case currentlyAsleep
    case noCrossing
}

/// Predicts the next sleep window from logged sleeps.
public struct Predictor: Sendable {
    public var curve: AgeCurve
    public var calendar: Calendar
    /// Half-width of the window, as an offset on the upper threshold.
    public var windowBand: Double = 0.01

    public init(curve: AgeCurve = .v1, calendar: Calendar = .current) {
        self.curve = curve
        self.calendar = calendar
    }

    /// Pressure now, replaying sleeps from the first wake-up, which is assumed to start at the lower threshold.
    public func pressure(params p: SleepPressureParams, sleeps: [SleepRecord], now: Date) throws -> Double {
        let sorted = sleeps.sorted { $0.start < $1.start }
        guard let firstEnd = sorted.first(where: { $0.end != nil })?.end else { throw PredictionError.noCompletedSleep }
        var s = p.lower(clockHour(firstEnd))
        var cursor = firstEnd
        for sleep in sorted where sleep.start >= firstEnd {
            guard sleep.start <= now else { break }
            s = p.risen(from: s, hours: hours(from: cursor, to: sleep.start))
            let end = min(sleep.end ?? now, now)
            s = p.decayed(from: s, hours: hours(from: sleep.start, to: end))
            cursor = end
        }
        return p.risen(from: s, hours: hours(from: cursor, to: now))
    }

    public func nextSleep(birthDate: Date, sleeps: [SleepRecord], now: Date) throws -> SleepPrediction {
        if sleeps.contains(where: { $0.end == nil }) { throw PredictionError.currentlyAsleep }
        let ageWeeks = hours(from: birthDate, to: now) / (24 * 7)
        let p = curve.params(ageWeeks: ageWeeks)
        let s = try pressure(params: p, sleeps: sleeps, now: now)
        let h = clockHour(now)
        guard let mid = p.hoursUntilCrossing(from: s, at: h) else { throw PredictionError.noCrossing }
        let early = p.hoursUntilCrossing(from: s, at: h, offset: -windowBand) ?? mid
        let late = p.hoursUntilCrossing(from: s, at: h, offset: windowBand) ?? mid
        let target = now.addingTimeInterval(mid * 3600)
        return SleepPrediction(
            target: target,
            earliest: now.addingTimeInterval(early * 3600),
            latest: now.addingTimeInterval(late * 3600),
            pressure: s,
            stage: AgeStage(ageWeeks: ageWeeks),
            reasons: reasons(params: p, sleeps: sleeps, targetHour: clockHour(target))
        )
    }

    private func reasons(params p: SleepPressureParams, sleeps: [SleepRecord], targetHour: Double) -> [PredictionReason] {
        var out: [PredictionReason] = []
        if let last = sleeps.filter({ $0.end != nil }).max(by: { $0.start < $1.start }), let end = last.end {
            let minutes = Int(hours(from: last.start, to: end) * 60)
            if minutes < 40 { out.append(.shortLastSleep(minutes: minutes)) }
            if minutes > 120 && minutes < 300 { out.append(.longLastSleep(minutes: minutes)) }
        }
        // Thresholds peak at phiHour (~6 pm) and then fall, which pulls bedtime in.
        let falling = sin(2 * .pi * (targetHour - p.phiHour) / 24) > 0
        if p.amplitude > 0, falling, (17...23).contains(Int(targetHour) % 24) {
            out.append(.eveningClock)
        }
        return out
    }

    func clockHour(_ date: Date) -> Double {
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
    }

    func hours(from a: Date, to b: Date) -> Double {
        b.timeIntervalSince(a) / 3600
    }
}
