import Foundation
@testable import SearchExplorer

/// Protocol-oriented fake for `SearchServing`.
actor FakeSearchService: SearchServing {
    struct Call: Sendable {
        let query: String
        let page: Int
        let perPage: Int
    }

    private(set) var calls: [Call] = []
    private var resultByQueryAndPage: [String: SearchPage] = [:]
    private var errorByQueryAndPage: [String: SearchError] = [:]
    private var error: SearchError?
    private var delayNanoseconds: UInt64 = 0

    func searchRepositories(query: String, page: Int, perPage: Int) async throws -> SearchPage {
        let delay = delayNanoseconds
        let errorSnapshot = error
        let key = self.key(query: query, page: page)
        let pageSnapshot = resultByQueryAndPage[key]
        let pageError = errorByQueryAndPage[key]

        calls.append(Call(query: query, page: page, perPage: perPage))
        if delay > 0 {
            try await Task.sleep(nanoseconds: delay)
        }
        try Task.checkCancellation()
        if let pageError {
            throw pageError
        }
        if let errorSnapshot {
            throw errorSnapshot
        }
        if let pageSnapshot {
            return pageSnapshot
        }
        return SearchPage(
            totalCount: 0,
            incompleteResults: false,
            items: [],
            page: page,
            perPage: perPage
        )
    }

    func setError(_ error: SearchError?) {
        self.error = error
    }

    func setError(_ error: SearchError, query: String, page: Int) {
        errorByQueryAndPage[key(query: query, page: page)] = error
    }

    func setResult(query: String, page: Int, result: SearchPage) {
        resultByQueryAndPage[key(query: query, page: page)] = result
    }

    func setDelay(_ nanoseconds: UInt64) {
        delayNanoseconds = nanoseconds
    }

    func callCount() -> Int {
        calls.count
    }

    /// Deterministic gate for race tests — polls until at least `count` calls have been recorded.
    func waitUntilCallCount(atLeast count: Int, timeout: Duration = .seconds(1)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while calls.count < count {
            if clock.now >= deadline {
                return false
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return true
    }

    private func key(query: String, page: Int) -> String {
        "\(query.lowercased())|\(page)"
    }
}
