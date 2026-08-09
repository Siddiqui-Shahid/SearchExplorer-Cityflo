import Foundation

protocol RecentSearchesStoring: Sendable {
    func load() async -> [String]
    func record(_ query: String) async -> [String]
    func clear() async
}
