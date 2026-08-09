import Foundation
@testable import SearchExplorer

/// In-memory `KeyValueStoring` fake for protocol-oriented persistence tests.
final class InMemoryKeyValueStore: KeyValueStoring, @unchecked Sendable {
    private var stringArrays: [String: [String]] = [:]

    func stringArray(forKey defaultName: String) -> [String]? {
        stringArrays[defaultName]
    }

    func set(_ value: [String], forKey defaultName: String) {
        stringArrays[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        stringArrays[defaultName] = nil
    }
}
