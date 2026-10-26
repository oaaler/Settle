import Foundation

/// Two-process sleep-pressure model (see docs/research/sleep-science.md §5).
///
/// Units: hours. Clock time is hours since local midnight (may exceed 24).
///
///     awake:  S rises toward 1 with time constant tauW
///     asleep: S decays toward 0 with time constant tauS
///     sleep window opens when S >= H(t) = h0 + amplitude * C(t)
///     natural wake when       S <= L(t) = h0 - gap + amplitude * C(t)
///     C(t) = cos(2π (t - phiHour) / 24)
public struct SleepPressureParams: Sendable, Equatable, Codable {
    public var tauW: Double
    public var tauS: Double
    public var h0: Double
    public var gap: Double
    public var amplitude: Double
    public var phiHour: Double

    public init(tauW: Double, tauS: Double, h0: Double, gap: Double, amplitude: Double, phiHour: Double) {
        self.tauW = tauW
        self.tauS = tauS
        self.h0 = h0
        self.gap = gap
        self.amplitude = amplitude
        self.phiHour = phiHour
    }

    public var l0: Double { h0 - gap }

    public func circadian(_ clockHour: Double) -> Double {
        cos(2 * .pi * (clockHour - phiHour) / 24)
    }

    /// Upper threshold: falling asleep becomes likely once pressure reaches it.
    public func upper(_ clockHour: Double) -> Double {
        h0 + amplitude * circadian(clockHour)
    }

    /// Lower threshold: spontaneous waking once pressure decays to it.
    public func lower(_ clockHour: Double) -> Double {
        l0 + amplitude * circadian(clockHour)
    }

    /// Pressure after `hours` awake, starting from `s`.
    public func risen(from s: Double, hours: Double) -> Double {
        1 - (1 - s) * exp(-hours / tauW)
    }

    /// Pressure after `hours` asleep, starting from `s`.
    public func decayed(from s: Double, hours: Double) -> Double {
        s * exp(-hours / tauS)
    }

    /// Hours awake until pressure reaches the upper threshold, starting at `clockHour` with pressure `s`.
    /// Returns nil if it is not reached within `horizon` hours.
    public func hoursUntilCrossing(
        from s: Double,
        at clockHour: Double,
        offset: Double = 0,
        horizon: Double = 30
    ) -> Double? {
        firstCrossing(horizon: horizon) { t in
            risen(from: s, hours: t) >= upper(clockHour + t) + offset
        }
    }

    /// Hours asleep until pressure drains to the lower threshold (natural waking).
    public func hoursUntilWake(from s: Double, at clockHour: Double, horizon: Double = 30) -> Double? {
        firstCrossing(horizon: horizon) { t in
            decayed(from: s, hours: t) <= lower(clockHour + t)
        }
    }

    /// Coarse 1-minute scan (matches tools/calibrate/model.py), then bisection refine.
    private func firstCrossing(horizon: Double, crossed: (Double) -> Bool) -> Double? {
        let step = 1.0 / 60
        var previous = 0.0
        var t = step
        while t <= horizon {
            if crossed(t) {
                var lo = previous
                var hi = t
                for _ in 0..<20 {
                    let mid = (lo + hi) / 2
                    if crossed(mid) { hi = mid } else { lo = mid }
                }
                return hi
            }
            previous = t
            t += step
        }
        return nil
    }
}

/// Global age curve: one parameter set varying smoothly with age (weeks).
/// Values come from tools/calibrate (out/curve.json); see sleep-science.md §6.
public struct AgeCurve: Sendable, Equatable, Codable {
    public var tauW52: Double
    public var kW: Double
    public var tauS52: Double
    public var kS: Double
    public var h0: Double
    public var gap: Double
    public var amplitudeMax: Double
    public var phiHour: Double

    public init(tauW52: Double, kW: Double, tauS52: Double, kS: Double, h0: Double, gap: Double, amplitudeMax: Double, phiHour: Double) {
        self.tauW52 = tauW52
        self.kW = kW
        self.tauS52 = tauS52
        self.kS = kS
        self.h0 = h0
        self.gap = gap
        self.amplitudeMax = amplitudeMax
        self.phiHour = phiHour
    }

    /// Calibration v1 (2026-10-26): joint age curve with replay check and tauS < tauW.
    public static let v1 = AgeCurve(
        tauW52: 7.757617831725497,
        kW: 0.2759348242784594,
        tauS52: 5.080912536846709,
        kS: 0.12872751257268408,
        h0: 0.37556354331001657,
        gap: 0.1696166879222496,
        amplitudeMax: 0.2039546790951404,
        phiHour: 16.65815874300957
    )

    /// Circadian strength ramps 0 → max between 8 and 16 weeks.
    public static func circadianRamp(ageWeeks: Double) -> Double {
        min(max((ageWeeks - 8) / 8, 0), 1)
    }

    public func params(ageWeeks: Double) -> SleepPressureParams {
        let r = max(ageWeeks, 0.5) / 52
        return SleepPressureParams(
            tauW: tauW52 * pow(r, kW),
            tauS: tauS52 * pow(r, kS),
            h0: h0,
            gap: gap,
            amplitude: amplitudeMax * Self.circadianRamp(ageWeeks: ageWeeks),
            phiHour: phiHour
        )
    }
}
