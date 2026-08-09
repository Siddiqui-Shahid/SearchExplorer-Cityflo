import Foundation
@testable import SearchExplorer

enum RepositoryFixtures {
    static func repository(
        id: Int,
        name: String = "demo",
        fullName: String? = nil
    ) -> Repository {
        Repository(
            id: id,
            name: name,
            fullName: fullName ?? "owner/\(name)",
            descriptionText: "A demo repository",
            stars: id * 10,
            language: "Swift",
            htmlURL: URL(string: "https://github.com/owner/\(name)")!,
            ownerLogin: "owner",
            ownerAvatarURL: URL(string: "https://avatars.githubusercontent.com/u/\(id)"),
            forks: 1,
            openIssues: 2,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    static func page(
        items: [Repository],
        totalCount: Int? = nil,
        page: Int = 1,
        perPage: Int = 30,
        incompleteResults: Bool = false
    ) -> SearchPage {
        SearchPage(
            totalCount: totalCount ?? items.count,
            incompleteResults: incompleteResults,
            items: items,
            page: page,
            perPage: perPage
        )
    }

    static let sampleSearchJSON = """
    {
      "total_count": 1,
      "incomplete_results": false,
      "items": [
        {
          "id": 42,
          "name": "swift",
          "full_name": "apple/swift",
          "description": "The Swift Programming Language",
          "stargazers_count": 999,
          "language": "C++",
          "html_url": "https://github.com/apple/swift",
          "forks_count": 10,
          "open_issues_count": 3,
          "updated_at": "2024-01-01T12:00:00Z",
          "owner": {
            "login": "apple",
            "avatar_url": "https://avatars.githubusercontent.com/u/1"
          }
        }
      ]
    }
    """.data(using: .utf8)!

    /// One valid row plus one with an empty `html_url` — client should drop the bad row.
    /// (`URL(string:)` is permissive; empty string is a reliable nil.)
    static let mixedValiditySearchJSON = """
    {
      "total_count": 2,
      "incomplete_results": false,
      "items": [
        {
          "id": 42,
          "name": "swift",
          "full_name": "apple/swift",
          "description": "The Swift Programming Language",
          "stargazers_count": 999,
          "language": "C++",
          "html_url": "https://github.com/apple/swift",
          "forks_count": 10,
          "open_issues_count": 3,
          "updated_at": "2024-01-01T12:00:00Z",
          "owner": {
            "login": "apple",
            "avatar_url": "https://avatars.githubusercontent.com/u/1"
          }
        },
        {
          "id": 99,
          "name": "broken",
          "full_name": "owner/broken",
          "description": null,
          "stargazers_count": 1,
          "language": null,
          "html_url": "",
          "forks_count": 0,
          "open_issues_count": 0,
          "updated_at": null,
          "owner": {
            "login": "owner",
            "avatar_url": null
          }
        }
      ]
    }
    """.data(using: .utf8)!
}
