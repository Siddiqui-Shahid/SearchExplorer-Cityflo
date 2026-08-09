import Foundation

/// Protocol-oriented seam over URLSession so networking can be faked in tests.
protocol HTTPDataServing: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataServing {}

/// Owns URLSession calls for repository search. Named deliberately — not the planted "CFNetworkConduit".
struct SearchNetworkClient: SearchServing {
    private let http: any HTTPDataServing
    private let baseURL: URL

    init(http: any HTTPDataServing = URLSession.shared) {
        self.http = http
        self.baseURL = URL(string: "https://api.github.com")!
    }

    func searchRepositories(query: String, page: Int, perPage: Int) async throws -> SearchPage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SearchError.emptyQuery }

        var components = URLComponents(
            url: baseURL.appending(path: "search/repositories"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage)),
            URLQueryItem(name: "sort", value: "stars"),
            URLQueryItem(name: "order", value: "desc"),
        ]

        guard let url = components?.url else { throw SearchError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("SearchExplorer-CityfloTakehome", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await http.data(for: request)
        } catch let urlError as URLError {
            if urlError.code == .cancelled || Task.isCancelled {
                throw SearchError.cancelled
            }
            if urlError.code == .notConnectedToInternet
                || urlError.code == .networkConnectionLost
                || urlError.code == .timedOut {
                throw SearchError.offline
            }
            throw SearchError.unknown(urlError.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw SearchError.unknown("Missing HTTP response.")
        }

        switch http.statusCode {
        case 200:
            break
        case 403, 429:
            let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw SearchError.rateLimited(retryAfter: retry)
        default:
            throw SearchError.httpStatus(http.statusCode)
        }

        let dto: GitHubSearchResponseDTO
        do {
            dto = try JSONDecoder().decode(GitHubSearchResponseDTO.self, from: data)
        } catch {
            throw SearchError.decodingFailed
        }

        // Drop malformed rows instead of failing the whole page (messy API reality).
        // Formatters stay local — ISO8601DateFormatter is not Sendable.
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        let items = dto.items.compactMap { item -> Repository? in
            item.toDomain(dateFormatter: fractional) ?? item.toDomain(dateFormatter: standard)
        }

        return SearchPage(
            totalCount: dto.totalCount,
            incompleteResults: dto.incompleteResults,
            items: items,
            page: page,
            perPage: perPage
        )
    }
}
