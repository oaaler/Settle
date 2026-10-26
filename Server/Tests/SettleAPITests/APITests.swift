import Foundation
import Hummingbird
import HummingbirdTesting
import Testing
@testable import SettleAPI

@Suite struct APITests {
    @Test func health() async throws {
        try await buildApplication().test(.router) { client in
            try await client.execute(uri: "/api/health", method: .get) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body).contains("\"ok\""))
            }
        }
    }

    @Test func simulateDay() async throws {
        try await buildApplication().test(.router) { client in
            try await client.execute(uri: "/api/v1/simulate/day?ageWeeks=30", method: .get) { response in
                #expect(response.status == .ok)
                let day = try JSONDecoder().decode(Day.self, from: Data(buffer: response.body))
                #expect(day.stage == "established")
                #expect(day.samples.count > 200)
            }
            try await client.execute(uri: "/api/v1/simulate/day?ageWeeks=200", method: .get) { response in
                #expect(response.status == .unprocessableContent)
            }
        }
    }

    @Test func sweepCoversTwoYears() async throws {
        try await buildApplication().test(.router) { client in
            try await client.execute(uri: "/api/v1/simulate/sweep", method: .get) { response in
                #expect(response.status == .ok)
                let sweep = try JSONDecoder().decode(Sweep.self, from: Data(buffer: response.body))
                #expect(sweep.points.count == 104)
            }
        }
    }

    @Test func dayPlan() async throws {
        let body = #"{"ageWeeks":30,"morningWake":6.75,"naps":[{"start":9,"end":10.25}],"now":11}"#
        try await buildApplication().test(.router) { client in
            try await client.execute(
                uri: "/api/v1/day-plan", method: .post, headers: [.contentType: "application/json"],
                body: ByteBuffer(string: body)
            ) { response in
                #expect(response.status == .ok)
                let plan = try JSONDecoder().decode(Plan.self, from: Data(buffer: response.body))
                #expect(plan.sleepWindow != nil)
                #expect(plan.plan.last?.kind == "night")
            }
        }
    }

    @Test func dayPlanRejectsImpossibleDay() async throws {
        let body = #"{"ageWeeks":30,"morningWake":7,"naps":[{"start":9,"end":13}],"now":12}"#
        try await buildApplication().test(.router) { client in
            try await client.execute(
                uri: "/api/v1/day-plan", method: .post, headers: [.contentType: "application/json"],
                body: ByteBuffer(string: body)
            ) { response in
                #expect(response.status == .unprocessableContent)
                #expect(String(buffer: response.body).contains("napInFuture"))
            }
        }
    }

    // Minimal client-side views of the responses (decoded independently of the generated types).
    struct Day: Decodable {
        let stage: String
        let samples: [Sample]
        struct Sample: Decodable { let hour: Double }
    }

    struct Sweep: Decodable {
        let points: [Point]
        struct Point: Decodable { let ageWeeks: Int }
    }

    struct Plan: Decodable {
        let sleepWindow: Window?
        let plan: [Planned]
        struct Window: Decodable { let target: Double }
        struct Planned: Decodable { let kind: String }
    }
}
