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
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(viewModel.recentSearches, ["swiftui"])
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
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(viewModel.phase, .loaded)
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
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(viewModel.phase, .empty)
        XCTAssertTrue(viewModel.results.isEmpty)
    }

    func testRateLimitMapsToFailedPhase() async {
        await searchService.setError(.rateLimited(retryAfter: 30))

        viewModel.query = "swift"
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(viewModel.phase, .failed(.rateLimited(retryAfter: 30)))
    }

    func testOfflineMapsToFailedPhase() async {
        await searchService.setError(.offline)

        viewModel.query = "swift"
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(viewModel.phase, .failed(.offline))
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
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(viewModel.phase, .loaded)

        viewModel.query = ""
        try? await Task.sleep(nanoseconds: 40_000_000)

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertTrue(viewModel.results.isEmpty)
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

        try? await Task.sleep(nanoseconds: 20_000_000)
        await searchService.setDelay(0)
        viewModel.query = "fast"

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.results.map(\.id), [2])
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
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(viewModel.results.count, 30)

        viewModel.loadMoreIfNeeded(currentItem: page1[28])
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(viewModel.results.count, 31)
        let calls = await searchService.callCount()
        XCTAssertEqual(calls, 2)
    }

    func testSelectRecentReusesProtocolBackedTerm() async {
        viewModel.onAppear()
        try? await Task.sleep(nanoseconds: 40_000_000)
        await searchService.setResult(
            query: "swiftui",
            page: 1,
            result: RepositoryFixtures.page(
                items: [RepositoryFixtures.repository(id: 9)],
                totalCount: 1
            )
        )

        viewModel.selectRecent("swiftui")
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(viewModel.query, "swiftui")
        XCTAssertEqual(viewModel.phase, .loaded)
    }

    func testClearRecentsUsesStoreProtocol() async {
        viewModel.onAppear()
        try? await Task.sleep(nanoseconds: 40_000_000)
        XCTAssertFalse(viewModel.recentSearches.isEmpty)

        viewModel.clearRecents()
        try? await Task.sleep(nanoseconds: 40_000_000)

        XCTAssertTrue(viewModel.recentSearches.isEmpty)
        let clearCount = await recentStore.clearCount
        XCTAssertEqual(clearCount, 1)
    }
}
