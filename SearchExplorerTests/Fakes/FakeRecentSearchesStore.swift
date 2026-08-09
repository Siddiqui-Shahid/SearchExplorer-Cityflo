import Foundation
@testable import SearchExplorer

/// Protocol-oriented fake for `RecentSearchesStoring`.
actor FakeRecentSearchesStore: RecentSearchesStoring {
    private var items: [String]
    private let limit: Int
    private(set) var clearCount = 0
    private(set) var recordCount = 0

    init(items: [String] = [], limit: Int = 10) {
        self.items = items
        self.limit = limit
    }

    func load() async -> [String] {
        items
    }

    func record(_ query: String) async -> [String] {
        recordCount += 1
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        items.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        items.insert(trimmed, at: 0)
        if items.count > limit {
            items = Array(items.prefix(limit))
        }
        return items
    }

    func clear() async {
        clearCount += 1
        items = []
    }
}
