import Testing
@testable import Settle

@Suite struct TodayModelTests {
    @Test func demoProducesAPrediction() {
        let model = TodayModel.demo()
        #expect(model.prediction != nil)
        #expect(model.windowText != "Log a sleep to start")
    }
}
