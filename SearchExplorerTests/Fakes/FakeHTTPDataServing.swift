import Foundation
@testable import SearchExplorer

/// Protocol-oriented fake for `HTTPDataServing`.
struct FakeHTTPDataServing: HTTPDataServing {
    var statusCode: Int = 200
    var body: Data = Data()
    var headers: [String: String] = [:]
    var error: Error?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error {
            throw error
        }
        let url = request.url ?? URL(string: "https://api.github.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return (body, response)
    }
}
