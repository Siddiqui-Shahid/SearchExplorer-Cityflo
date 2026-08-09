import XCTest
@testable import SearchExplorer

@MainActor
final class SearchViewModelTests: XCTestCase {
    private var searchService: FakeSearchService!
    private var recentStore: FakeRecentSearchesStore!
    private var viewModel: SearchViewModel!

    override func setUp() async throws {
        searchService = FakeSearchService()
        recentStore = FakeRecentSearchesStore(items: ["swiftui"])
        viewModel = SearchViewModel(
            searchService: searchService,
            recentStore: recentStore,
            debounceNanoseconds: 0
        )
    }

    func testOnAppearLoadsRecentsViaProtocol() async {
        viewModel.onAppear()
        await AsyncTestWait.until { viewModel.recentSearches == ["swiftui"] }
    }

    func testSuccessfulSearchUpdatesResultsAndRecordsRecent() async {
        await searchService.setResult(
            query: "explorer",
            page: 1,
            result: RepositoryFixtures.page(
                items: [RepositoryFixtures.repository(id: 1, name: "search-explorer")],
                totalCount: 1
            )
        )

        viewModel.query = "explorer"
        await AsyncTestWait.until { viewModel.phase == .loaded }

        XCTAssertEqual(viewModel.results.map(\.id), [1])
        XCTAssertEqual(viewModel.recentSearches.first, "explorer")
        let calls = await searchService.callCount()
        XCTAssertEqual(calls, 1)
    }

    func testEmptyResultsSurfaceEmptyPhase() async {
        await searchService.setResult(
            query: "zzzz-no-hits",
            page: 1,
            result: RepositoryFixtures.page(items: [], totalCount: 0)
        )

        viewModel.query = "zzzz-no-hits"
        await AsyncTestWait.until { viewModel.phase == .empty }
        XCTAssertTrue(viewModel.results.isEmpty)
    }

    func testRateLimitMapsToFailedPhase() async {
        await searchService.setError(.rateLimited(retryAfter: 30))

        viewModel.query = "swift"
        await AsyncTestWait.until {
            viewModel.phase == .failed(.rateLimited(retryAfter: 30))
        }
    }

    func testOfflineMapsToFailedPhase() async {
        await searchService.setError(.offline)

        viewModel.query = "swift"
        await AsyncTestWait.until { viewModel.phase == .failed(.offline) }
    }

    func testClearingQueryReturnsToIdleAndDropsResults() async {
        await searchService.setResult(
            query: "keep",
            page: 1,
            result: RepositoryFixtures.page(
                items: [RepositoryFixtures.repository(id: 7)],
                totalCount: 1
            )
        )

        viewModel.query = "keep"
        await AsyncTestWait.until { viewModel.phase == .loaded }

        viewModel.query = ""
        await AsyncTestWait.until { viewModel.phase == .idle }
        XCTAssertTrue(viewModel.results.isEmpty)
    }

    func testWhitespaceOnlyQueryDoesNotSearch() async {
        viewModel.query = "   "
        await AsyncTestWait.until { viewModel.phase == .idle }
        let calls = await searchService.callCount()
        XCTAssertEqual(calls, 0)
    }

    func testStaleResponseDoesNotStompNewerQuery() async {
        await searchService.setResult(
            query: "slow",
            page: 1,
            result: RepositoryFixtures.page(
                items: [RepositoryFixtures.repository(id: 1, name: "slow")],
                totalCount: 1
            )
        )
        await searchService.setResult(
            query: "fast",
            page: 1,
            result: RepositoryFixtures.page(
                items: [RepositoryFixtures.repository(id: 2, name: "fast")],
                totalCount: 1
            )
        )
        await searchService.setDelay(120_000_000)

        viewModel.query = "slow"
        let started = await searchService.waitUntilCallCount(atLeast: 1)
        XCTAssertTrue(started, "Expected slow search to begin before superseding it")
        await searchService.setDelay(0)
        viewModel.query = "fast"

        await AsyncTestWait.until { viewModel.results.map(\.id) == [2] }
        XCTAssertEqual(viewModel.phase, .loaded)
    }

    func testLoadMoreAppendsNextPageViaProtocol() async {
        let page1 = (1...30).map { RepositoryFixtures.repository(id: $0, name: "r\($0)") }
        let page2 = [RepositoryFixtures.repository(id: 31, name: "r31")]
        await searchService.setResult(
            query: "paged",
            page: 1,
            result: RepositoryFixtures.page(items: page1, totalCount: 31, page: 1)
        )
        await searchService.setResult(
            query: "paged",
            page: 2,
            result: RepositoryFixtures.page(items: page2, totalCount: 31, page: 2)
        )

        viewModel.query = "paged"
        await AsyncTestWait.until { viewModel.results.count == 30 }

        viewModel.loadMoreIfNeeded(currentItem: page1[28])
        await AsyncTestWait.until { viewModel.results.count == 31 }
        let calls = await searchService.callCount()
        XCTAssertEqual(calls, 2)
    }

    func testLoadMoreDoesNotFireWhenPageExhaustsTotalCount() async {
        let onlyPage = [RepositoryFixtures.repository(id: 1, name: "solo")]
        await searchService.setResult(
            query: "exact",
            page: 1,
            result: RepositoryFixtures.page(items: onlyPage, totalCount: 1, page: 1)
        )

        viewModel.query = "exact"
        await AsyncTestWait.until { viewModel.phase == .loaded }

        viewModel.loadMoreIfNeeded(currentItem: onlyPage[0])
        let calls = await searchService.callCount()
        XCTAssertEqual(calls, 1)
    }

    func testResultWindowExhaustedStopsFurtherPagination() async {
        let page1 = (1...30).map { RepositoryFixtures.repository(id: $0, name: "r\($0)") }
        await searchService.setResult(
            query: "huge",
            page: 1,
            result: RepositoryFixtures.page(items: page1, totalCount: 50_000, page: 1)
        )
        await searchService.setError(.resultWindowExhausted, query: "huge", page: 2)

        viewModel.query = "huge"
        await AsyncTestWait.until { viewModel.results.count == 30 }

        viewModel.loadMoreIfNeeded(currentItem: page1[28])
        await AsyncTestWait.until { viewModel.isLoadingMore == false }

        XCTAssertEqual(viewModel.results.count, 30)
        XCTAssertEqual(viewModel.phase, .loaded)

        let callsAfterCap = await searchService.callCount()
        XCTAssertEqual(callsAfterCap, 2)

        viewModel.loadMoreIfNeeded(currentItem: page1[28])
        let callsAfterRetry = await searchService.callCount()
        XCTAssertEqual(callsAfterRetry, 2, "canLoadMore should stay false after result window exhaustion")
    }

    func testPaginationFailureKeepsExistingResults() async {
        let page1 = (1...30).map { RepositoryFixtures.repository(id: $0, name: "r\($0)") }
        await searchService.setResult(
            query: "paged",
            page: 1,
            result: RepositoryFixtures.page(items: page1, totalCount: 60, page: 1)
        )

        viewModel.query = "paged"
        await AsyncTestWait.until { viewModel.results.count == 30 }

        await searchService.setError(.offline)
        viewModel.loadMoreIfNeeded(currentItem: page1[28])
        await AsyncTestWait.until { viewModel.isLoadingMore == false }

        XCTAssertEqual(viewModel.results.count, 30)
        XCTAssertEqual(viewModel.phase, .loaded)
    }

    func testRetryReissuesImmediateSearch() async {
        await searchService.setError(.offline)
        viewModel.query = "swift"
        await AsyncTestWait.until { viewModel.phase == .failed(.offline) }

        await searchService.setError(nil)
        await searchService.setResult(
            query: "swift",
            page: 1,
            result: RepositoryFixtures.page(
                items: [RepositoryFixtures.repository(id: 3)],
                totalCount: 1
            )
        )

        viewModel.retry()
        await AsyncTestWait.until { viewModel.phase == .loaded }
        XCTAssertEqual(viewModel.results.map(\.id), [3])
    }

    func testSelectRecentReusesProtocolBackedTerm() async {
        viewModel.onAppear()
        await AsyncTestWait.until { viewModel.recentSearches == ["swiftui"] }
        await searchService.setResult(
            query: "swiftui",
            page: 1,
            result: RepositoryFixtures.page(
                items: [RepositoryFixtures.repository(id: 9)],
                totalCount: 1
            )
        )

        viewModel.selectRecent("swiftui")
        await AsyncTestWait.until { viewModel.phase == .loaded }
        XCTAssertEqual(viewModel.query, "swiftui")
    }

    func testClearRecentsUsesStoreProtocol() async {
        viewModel.onAppear()
        await AsyncTestWait.until { !viewModel.recentSearches.isEmpty }

        viewModel.clearRecents()
        await AsyncTestWait.until { viewModel.recentSearches.isEmpty }
        let clearCount = await recentStore.clearCount
        XCTAssertEqual(clearCount, 1)
    }

    func testIncompleteResultsFlagSurfacesFromPage() async {
        await searchService.setResult(
            query: "partial",
            page: 1,
            result: RepositoryFixtures.page(
                items: [RepositoryFixtures.repository(id: 5)],
                totalCount: 1,
                incompleteResults: true
            )
        )

        viewModel.query = "partial"
        await AsyncTestWait.until { viewModel.phase == .loaded }
        XCTAssertTrue(viewModel.incompleteResults)
    }
}
