import Foundation

actor RecentSearchesStore: RecentSearchesStoring {
    static let defaultLimit = 10

    private let storage: any KeyValueStoring
    private let key: String
    private let limit: Int

    init(
        storage: any KeyValueStoring = UserDefaultsKeyValueStore(),
        key: String = "search_explorer.recent_queries",
        limit: Int = RecentSearchesStore.defaultLimit
    ) {
        self.storage = storage
        self.key = key
        self.limit = limit
    }

    func load() async -> [String] {
        storage.stringArray(forKey: key) ?? []
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
        storage.set(current, forKey: key)
        return current
    }

    func clear() async {
        storage.removeObject(forKey: key)
    }
}
