import Foundation

enum SearchError: Error, Equatable, Sendable {
    case emptyQuery
    case invalidURL
    case offline
    case rateLimited(retryAfter: TimeInterval?)
    /// GitHub search only returns the first 1,000 hits; further pages 422.
    case resultWindowExhausted
    case httpStatus(Int)
    case decodingFailed
    case cancelled
    case unknown(String)

    var title: String {
        switch self {
        case .offline:
            "You're offline"
        case .rateLimited:
            "Rate limit reached"
        case .emptyQuery:
            "Nothing to search"
        case .resultWindowExhausted:
            "End of results"
        case .decodingFailed, .invalidURL:
            "Unexpected response"
        case .httpStatus, .unknown:
            "Search failed"
        case .cancelled:
            "Search cancelled"
        }
    }

    var systemImage: String {
        switch self {
        case .offline:
            "wifi.slash"
        case .rateLimited:
            "hourglass"
        case .emptyQuery:
            "magnifyingglass"
        case .resultWindowExhausted:
            "tray"
        case .decodingFailed, .invalidURL:
            "wrench.and.screwdriver"
        case .httpStatus, .unknown, .cancelled:
            "exclamationmark.triangle"
        }
    }

    var userMessage: String {
        switch self {
        case .emptyQuery:
            "Enter a search term to explore repositories."
        case .invalidURL:
            "Could not build a valid search request."
        case .offline:
            "Check your connection and try again."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                "GitHub asked us to slow down. Try again in about \(Int(retryAfter.rounded()))s."
            } else {
                "GitHub asked us to slow down. Wait a moment and try again."
            }
        case .resultWindowExhausted:
            "GitHub only returns the first 1,000 matching repositories."
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
