import XCTest

@MainActor
enum AsyncTestWait {
    /// Polls until `condition` is true or fails the test after `timeout`.
    static func until(
        timeout: Duration = .seconds(1),
        pollNanoseconds: UInt64 = 10_000_000,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @MainActor () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        XCTFail("Condition not met within \(timeout)", file: file, line: line)
    }
}
