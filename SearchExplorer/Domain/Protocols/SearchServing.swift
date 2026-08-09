import Foundation

protocol SearchServing: Sendable {
    func searchRepositories(query: String, page: Int, perPage: Int) async throws -> SearchPage
}
