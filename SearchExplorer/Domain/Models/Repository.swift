import Foundation

struct Repository: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let fullName: String
    let descriptionText: String?
    let stars: Int
    let language: String?
    let htmlURL: URL
    let ownerLogin: String
    let ownerAvatarURL: URL?
    let forks: Int
    let openIssues: Int
    let updatedAt: Date?
}

struct SearchPage: Sendable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [Repository]
    let page: Int
    let perPage: Int

    /// True when this page is non-empty and more pages remain by GitHub's totals.
    var canLoadMore: Bool {
        guard !items.isEmpty else { return false }
        return page * perPage < totalCount
    }
}
