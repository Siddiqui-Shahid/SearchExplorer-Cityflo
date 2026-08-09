import Foundation

/// Protocol-oriented seam over URLSession so networking can be faked in tests.
protocol HTTPDataServing: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataServing {}
