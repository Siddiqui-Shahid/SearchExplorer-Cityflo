import XCTest
@testable import SearchExplorer

final class SearchNetworkClientTests: XCTestCase {
    func testEmptyQueryThrowsWithoutHittingHTTP() async {
        let http = FakeHTTPDataServing()
        http.statusCode = 500
        let client = SearchNetworkClient(http: http)

        do {
            _ = try await client.searchRepositories(query: "  ", page: 1, perPage: 30)
            XCTFail("Expected emptyQuery")
        } catch let error as SearchError {
            XCTAssertEqual(error, .emptyQuery)
            XCTAssertEqual(http.requestCount, 0)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testDecodesSuccessfulPayloadViaHTTPProtocol() async throws {
        let http = FakeHTTPDataServing()
        http.statusCode = 200
        http.body = RepositoryFixtures.sampleSearchJSON
        let client = SearchNetworkClient(http: http)

        let page = try await client.searchRepositories(query: "swift", page: 1, perPage: 30)

        XCTAssertEqual(page.totalCount, 1)
        XCTAssertEqual(page.items.first?.fullName, "apple/swift")
        XCTAssertEqual(page.items.first?.stars, 999)
        XCTAssertEqual(page.items.first?.ownerLogin, "apple")
        XCTAssertEqual(http.requestCount, 1)
    }

    func testHTTP403MapsToRateLimited() async {
        let http = FakeHTTPDataServing()
        http.statusCode = 403
        http.headers = ["Retry-After": "12"]
        let client = SearchNetworkClient(http: http)

        do {
            _ = try await client.searchRepositories(query: "swift", page: 1, perPage: 30)
            XCTFail("Expected rateLimited")
        } catch let error as SearchError {
            XCTAssertEqual(error, .rateLimited(retryAfter: 12))
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testHTTP429MapsToRateLimited() async {
        let http = FakeHTTPDataServing()
        http.statusCode = 429
        let client = SearchNetworkClient(http: http)

        do {
            _ = try await client.searchRepositories(query: "swift", page: 1, perPage: 30)
            XCTFail("Expected rateLimited")
        } catch let error as SearchError {
            XCTAssertEqual(error, .rateLimited(retryAfter: nil))
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testHTTP422MapsToResultWindowExhausted() async {
        let http = FakeHTTPDataServing()
        http.statusCode = 422
        let client = SearchNetworkClient(http: http)

        do {
            _ = try await client.searchRepositories(query: "swift", page: 34, perPage: 30)
            XCTFail("Expected resultWindowExhausted")
        } catch let error as SearchError {
            XCTAssertEqual(error, .resultWindowExhausted)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testHTTP500MapsToHttpStatus() async {
        let http = FakeHTTPDataServing()
        http.statusCode = 500
        let client = SearchNetworkClient(http: http)

        do {
            _ = try await client.searchRepositories(query: "swift", page: 1, perPage: 30)
            XCTFail("Expected httpStatus")
        } catch let error as SearchError {
            XCTAssertEqual(error, .httpStatus(500))
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testOfflineURLErrorMapsToOffline() async {
        let http = FakeHTTPDataServing()
        http.error = URLError(.notConnectedToInternet)
        let client = SearchNetworkClient(http: http)

        do {
            _ = try await client.searchRepositories(query: "swift", page: 1, perPage: 30)
            XCTFail("Expected offline")
        } catch let error as SearchError {
            XCTAssertEqual(error, .offline)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testTimedOutURLErrorMapsToOffline() async {
        let http = FakeHTTPDataServing()
        http.error = URLError(.timedOut)
        let client = SearchNetworkClient(http: http)

        do {
            _ = try await client.searchRepositories(query: "swift", page: 1, perPage: 30)
            XCTFail("Expected offline")
        } catch let error as SearchError {
            XCTAssertEqual(error, .offline)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testMalformedJSONMapsToDecodingFailed() async {
        let http = FakeHTTPDataServing()
        http.statusCode = 200
        http.body = Data("not-json".utf8)
        let client = SearchNetworkClient(http: http)

        do {
            _ = try await client.searchRepositories(query: "swift", page: 1, perPage: 30)
            XCTFail("Expected decodingFailed")
        } catch let error as SearchError {
            XCTAssertEqual(error, .decodingFailed)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testDropsMalformedRowsInsteadOfFailingPage() async throws {
        let http = FakeHTTPDataServing()
        http.statusCode = 200
        http.body = RepositoryFixtures.mixedValiditySearchJSON
        let client = SearchNetworkClient(http: http)

        let page = try await client.searchRepositories(query: "swift", page: 1, perPage: 30)

        XCTAssertEqual(page.totalCount, 2)
        XCTAssertEqual(page.items.map(\.id), [42])
        XCTAssertEqual(page.items.first?.fullName, "apple/swift")
    }

    func testCanLoadMoreUsesPageAndPerPageAgainstTotal() {
        let full = RepositoryFixtures.page(
            items: (1...30).map { RepositoryFixtures.repository(id: $0) },
            totalCount: 60,
            page: 1,
            perPage: 30
        )
        XCTAssertTrue(full.canLoadMore)

        let last = RepositoryFixtures.page(
            items: [RepositoryFixtures.repository(id: 31)],
            totalCount: 31,
            page: 2,
            perPage: 30
        )
        XCTAssertFalse(last.canLoadMore)
    }
}
