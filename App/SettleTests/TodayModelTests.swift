import Testing
@testable import Settle

@Suite struct TodayModelTests {
    @Test func demoProducesASleepWindow() {
        let model = TodayModel.demo()
        #expect(model.sleepWindow != nil)
        #expect(model.windowText != "Log a sleep to start")
    }
}
