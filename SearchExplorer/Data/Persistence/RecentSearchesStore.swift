import Foundation

actor RecentSearchesStore: RecentSearchesStoring {
    static let defaultLimit = 10

    private let defaults: UserDefaults
    private let key: String
    private let limit: Int

    init(
        defaults: UserDefaults = .standard,
        key: String = "search_explorer.recent_queries",
        limit: Int = RecentSearchesStore.defaultLimit
    ) {
        self.defaults = defaults
        self.key = key
        self.limit = limit
    }

    func load() async -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func record(_ query: String) async -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return await load() }

        var current = await load()
        current.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        current.insert(trimmed, at: 0)
        if current.count > limit {
            current = Array(current.prefix(limit))
        }
        defaults.set(current, forKey: key)
        return current
    }

    func clear() async {
        defaults.removeObject(forKey: key)
    }
}
