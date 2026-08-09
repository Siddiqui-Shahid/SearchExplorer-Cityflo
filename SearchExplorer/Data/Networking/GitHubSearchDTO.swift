import Foundation

struct GitHubSearchResponseDTO: Decodable, Sendable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [GitHubRepositoryDTO]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}

struct GitHubRepositoryDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let stargazersCount: Int
    let language: String?
    let htmlURL: String
    let forksCount: Int
    let openIssuesCount: Int
    let updatedAt: String?
    let owner: GitHubOwnerDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case fullName = "full_name"
        case description
        case stargazersCount = "stargazers_count"
        case language
        case htmlURL = "html_url"
        case forksCount = "forks_count"
        case openIssuesCount = "open_issues_count"
        case updatedAt = "updated_at"
        case owner
    }

    func toDomain(dateFormatter: ISO8601DateFormatter) -> Repository? {
        guard let htmlURL = URL(string: htmlURL) else { return nil }
        let avatarURL = owner?.avatarURL.flatMap(URL.init(string:))
        let updated = updatedAt.flatMap { dateFormatter.date(from: $0) }
        return Repository(
            id: id,
            name: name,
            fullName: fullName,
            descriptionText: description,
            stars: stargazersCount,
            language: language,
            htmlURL: htmlURL,
            ownerLogin: owner?.login ?? "unknown",
            ownerAvatarURL: avatarURL,
            forks: forksCount,
            openIssues: openIssuesCount,
            updatedAt: updated
        )
    }
}

struct GitHubOwnerDTO: Decodable, Sendable {
    let login: String
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case login
        case avatarURL = "avatar_url"
    }
}
