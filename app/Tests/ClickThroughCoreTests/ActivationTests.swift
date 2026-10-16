import Testing
@testable import ClickThroughCore

@Test func applicationRequestFollowsSuccessfulWindowRequestExactlyOnce() {
    var calls: [String] = []
    let proceeded = ActivationSequence.run(window: {
        calls.append("window")
        return true
    }, application: {
        calls.append("application")
    })
    #expect(proceeded)
    #expect(calls == ["window", "application"])
}

@Test func failedWindowRequestNeverFallsBackOrRetries() {
    var windowRequests = 0
    var applicationRequests = 0
    let proceeded = ActivationSequence.run(window: {
        windowRequests += 1
        return false
    }, application: {
        applicationRequests += 1
    })
    #expect(!proceeded)
    #expect(windowRequests == 1)
    #expect(applicationRequests == 0)
}
