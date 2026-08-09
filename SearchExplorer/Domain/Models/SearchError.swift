import Foundation

enum SearchError: Error, Equatable, Sendable {
    case emptyQuery
    case invalidURL
    case offline
    case rateLimited(retryAfter: TimeInterval?)
    case httpStatus(Int)
    case decodingFailed
    case cancelled
    case unknown(String)

    var userMessage: String {
        switch self {
        case .emptyQuery:
            "Enter a search term to explore repositories."
        case .invalidURL:
            "Could not build a valid search request."
        case .offline:
            "You appear to be offline. Check your connection and try again."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                "GitHub rate limit hit. Try again in about \(Int(retryAfter.rounded()))s."
            } else {
                "GitHub rate limit hit. Wait a moment and try again."
            }
        case .httpStatus(let code):
            "Server returned \(code). Try again shortly."
        case .decodingFailed:
            "Received an unexpected response from GitHub."
        case .cancelled:
            "Search cancelled."
        case .unknown(let message):
            message
        }
    }
}
