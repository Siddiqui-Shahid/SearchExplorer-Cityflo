import XCTest
@testable import SearchExplorer

final class SearchNetworkClientTests: XCTestCase {
    func testEmptyQueryThrowsWithoutHittingHTTP() async {
        var http = FakeHTTPDataServing()
        http.statusCode = 500
        let client = SearchNetworkClient(http: http)

        do {
            _ = try await client.searchRepositories(query: "  ", page: 1, perPage: 30)
            XCTFail("Expected emptyQuery")
        } catch let error as SearchError {
            XCTAssertEqual(error, .emptyQuery)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testDecodesSuccessfulPayloadViaHTTPProtocol() async throws {
        var http = FakeHTTPDataServing()
        http.statusCode = 200
        http.body = RepositoryFixtures.sampleSearchJSON
        let client = SearchNetworkClient(http: http)

        let page = try await client.searchRepositories(query: "swift", page: 1, perPage: 30)

        XCTAssertEqual(page.totalCount, 1)
        XCTAssertEqual(page.items.first?.fullName, "apple/swift")
        XCTAssertEqual(page.items.first?.stars, 999)
        XCTAssertEqual(page.items.first?.ownerLogin, "apple")
    }

    func testHTTP403MapsToRateLimited() async {
        var http = FakeHTTPDataServing()
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

    func testOfflineURLErrorMapsToOffline() async {
        var http = FakeHTTPDataServing()
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

    func testMalformedJSONMapsToDecodingFailed() async {
        var http = FakeHTTPDataServing()
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
}
