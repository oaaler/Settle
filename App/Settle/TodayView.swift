import SettleCore
import SwiftUI

/// Placeholder Today screen wired to the engine with demo data, so CI exercises the app → SettleCore path.
struct TodayView: View {
    let model = TodayModel.demo()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Next nap")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(model.windowText)
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                if let reason = model.reasonText {
                    Text(reason)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .navigationTitle("Today")
        }
    }
}

struct TodayModel {
    var prediction: SleepPrediction?

    var windowText: String {
        guard let p = prediction else { return "Log a sleep to start" }
        let f = Date.FormatStyle(date: .omitted, time: .shortened)
        return "\(p.earliest.formatted(f)) – \(p.latest.formatted(f))"
    }

    var reasonText: String? {
        switch prediction?.reasons.first {
        case .shortLastSleep(let minutes): "Short nap (\(minutes)m) → shorter wake window"
        case .longLastSleep(let minutes): "Long nap (\(minutes)m) → longer wake window"
        case .eveningClock: "Evening: body clock is winding down"
        case nil: nil
        }
    }

    static func demo(now: Date = .now) -> TodayModel {
        let cal = Calendar.current
        let birth = cal.date(byAdding: .month, value: -7, to: now) ?? now
        let wake = now.addingTimeInterval(-4 * 3600)
        let sleeps = [
            SleepRecord(start: wake.addingTimeInterval(-11 * 3600), end: wake),
            SleepRecord(start: wake.addingTimeInterval(2 * 3600), end: wake.addingTimeInterval(3.25 * 3600)),
        ]
        return TodayModel(prediction: try? Predictor().nextSleep(birthDate: birth, sleeps: sleeps, now: now))
    }
}

#Preview {
    TodayView()
}
