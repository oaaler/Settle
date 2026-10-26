import SettleCore

// SettleCore → generated API types. Kept in one place so the contract and the engine meet here only.

extension Components.Schemas.AgeCurve {
    init(_ c: AgeCurve) {
        self.init(
            tauW52: c.tauW52, kW: c.kW, tauS52: c.tauS52, kS: c.kS,
            h0: c.h0, gap: c.gap, amplitudeMax: c.amplitudeMax, phiHour: c.phiHour
        )
    }
}

extension Components.Schemas.ModelParams {
    init(_ p: SleepPressureParams) {
        self.init(tauW: p.tauW, tauS: p.tauS, h0: p.h0, gap: p.gap, amplitude: p.amplitude, phiHour: p.phiHour)
    }
}

extension Components.Schemas.AgeStage {
    init(_ s: AgeStage) {
        switch s {
        case .newborn: self = .newborn
        case .emerging: self = .emerging
        case .established: self = .established
        }
    }
}

extension Components.Schemas.PressureSample {
    init(_ s: SettleCore.PressureSample) {
        self.init(hour: s.hour, pressure: s.pressure, upper: s.upper, lower: s.lower, asleep: s.asleep)
    }
}

extension Components.Schemas.DaySummary {
    init(_ s: SettleCore.DaySummary) {
        self.init(
            sleepBouts: s.sleepBouts,
            totalSleepHours: s.totalSleepHours,
            naps: s.naps,
            nightSleepHours: s.nightSleepHours,
            daySleepHours: s.daySleepHours,
            wakeWindows: s.wakeWindows,
            morningWake: s.morningWakeHour,
            nightSleepStart: s.nightSleepStartHour
        )
    }
}

extension Components.Schemas.SimulatedDay {
    init(_ d: SettleCore.SimulatedDay) {
        self.init(
            ageWeeks: d.ageWeeks,
            stage: .init(d.stage),
            params: .init(d.params),
            bouts: d.bouts.map { .init(start: $0.start, end: $0.end) },
            samples: d.samples.map { .init($0) },
            summary: .init(d.summary)
        )
    }
}

extension Components.Schemas.Reason {
    init(_ r: PredictionReason) {
        switch r {
        case .shortLastSleep(let minutes): self.init(kind: .shortLastSleep, minutes: minutes)
        case .longLastSleep(let minutes): self.init(kind: .longLastSleep, minutes: minutes)
        case .eveningClock: self.init(kind: .eveningClock)
        }
    }
}

extension Components.Schemas.DayPlan {
    init(_ d: SettleCore.DayPlan) {
        self.init(
            stage: .init(d.stage),
            params: .init(d.params),
            pressureNow: d.pressureNow,
            asleepNow: d.asleepNow,
            sleepWindow: d.sleepWindow.map { .init(earliest: $0.earliest, target: $0.target, latest: $0.latest) },
            reasons: d.reasons.map { .init($0) },
            plan: d.plan.map { .init(kind: $0.kind == .nap ? .nap : .night, start: $0.start, end: $0.end, inProgress: $0.inProgress) },
            samples: d.samples.map { .init($0) }
        )
    }
}
