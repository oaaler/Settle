import Foundation
import SettleAPI

let env = ProcessInfo.processInfo.environment
let host = env["HOST"] ?? "0.0.0.0"
let port = env["PORT"].flatMap(Int.init) ?? 8080

let app = try buildApplication(host: host, port: port)
try await app.runService()
