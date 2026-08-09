import Foundation
@testable import SearchExplorer

/// Mutable HTTP fake. Class (not struct) so request counting survives across awaits.
final class FakeHTTPDataServing: HTTPDataServing, @unchecked Sendable {
    var statusCode: Int = 200
    var body: Data = Data()
    var headers: [String: String] = [:]
    var error: Error?
    private(set) var requestCount = 0
    private(set) var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        lastRequest = request
        if let error {
            throw error
        }
        let url = request.url ?? URL(string: "https://api.github.com/search/repositories")!
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            throw URLError(.badServerResponse)
        }
        return (body, response)
    }
}
