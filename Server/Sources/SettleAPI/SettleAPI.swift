import Foundation
import Hummingbird
import OpenAPIHummingbird
import OpenAPIRuntime
import SettleCore

/// Implements the generated `APIProtocol` (from openapi.yaml) on top of SettleCore. Stateless.
struct SettleAPIImpl: APIProtocol {
    var curve: AgeCurve = .v1
    var sweep: Components.Schemas.Sweep

    init(curve: AgeCurve = .v1) {
        self.curve = curve
        // The sweep depends only on the curve, so compute it once at startup.
        self.sweep = .init(points: Simulator.sweep(curve: curve).map { .init(ageWeeks: $0.ageWeeks, summary: .init($0.summary)) })
    }

    func getHealth(_ input: Operations.GetHealth.Input) async throws -> Operations.GetHealth.Output {
        .ok(.init(body: .json(.init(status: .ok))))
    }

    func getModel(_ input: Operations.GetModel.Input) async throws -> Operations.GetModel.Output {
        .ok(.init(body: .json(.init(calibration: "v1", ageCurve: .init(curve)))))
    }

    func simulateDay(_ input: Operations.SimulateDay.Input) async throws -> Operations.SimulateDay.Output {
        let age = input.query.ageWeeks
        guard (0.5...104).contains(age) else {
            return .unprocessableContent(.init(body: .json(.init(code: "ageOutOfRange", message: "ageWeeks must be 0.5–104"))))
        }
        guard let day = Simulator.day(ageWeeks: age, curve: curve) else {
            return .unprocessableContent(.init(body: .json(.init(code: "modelStuck", message: "The model did not settle at this age"))))
        }
        return .ok(.init(body: .json(.init(day))))
    }

    func simulateSweep(_ input: Operations.SimulateSweep.Input) async throws -> Operations.SimulateSweep.Output {
        .ok(.init(body: .json(sweep)))
    }

    func planDay(_ input: Operations.PlanDay.Input) async throws -> Operations.PlanDay.Output {
        guard case .json(let request) = input.body else { throw APIError.unsupportedBody }
        guard (0.5...104).contains(request.ageWeeks) else {
            return .unprocessableContent(.init(body: .json(.init(code: "ageOutOfRange", message: "ageWeeks must be 0.5–104"))))
        }
        do {
            let plan = try DayPlanner(curve: curve).plan(
                ageWeeks: request.ageWeeks,
                morningWake: request.morningWake,
                naps: request.naps.map { LoggedNap(start: $0.start, end: $0.end) },
                now: request.now
            )
            return .ok(.init(body: .json(.init(plan))))
        } catch let error as DayPlanError {
            return .unprocessableContent(.init(body: .json(.init(code: "\(error)", message: error.message))))
        }
    }
}

enum APIError: Error {
    case unsupportedBody
}

extension DayPlanError {
    var message: String {
        switch self {
        case .napBeforeMorningWake: "A nap starts before the morning wake."
        case .napsOverlapOrUnordered: "Naps overlap or are out of order."
        case .napInFuture: "A nap starts or ends after now."
        case .napEndsBeforeStart: "A nap ends before it starts."
        case .onlyLastNapMayBeOngoing: "Only the last nap can be in progress."
        case .nowBeforeMorningWake: "Now is before the morning wake."
        case .modelStuck: "The model could not plan this day."
        }
    }
}

/// Builds the Hummingbird application. The API is served under /api (see `servers` in openapi.yaml).
public func buildApplication(host: String = "127.0.0.1", port: Int = 8080) throws -> some ApplicationProtocol {
    let router = Router()
    router.middlewares.add(LogRequestsMiddleware(.info))
    let api = SettleAPIImpl()
    try api.registerHandlers(on: router, serverURL: Servers.Server1.url())
    return Application(
        router: router,
        configuration: .init(address: .hostname(host, port: port), serverName: "settle-api")
    )
}
