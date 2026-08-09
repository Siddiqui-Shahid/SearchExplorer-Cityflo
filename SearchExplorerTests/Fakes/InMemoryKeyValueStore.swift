import Foundation
@testable import SearchExplorer

/// In-memory `KeyValueStoring` fake. Locked so `@unchecked Sendable` is honest under concurrent actor hops.
final class InMemoryKeyValueStore: KeyValueStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var stringArrays: [String: [String]] = [:]

    func stringArray(forKey defaultName: String) -> [String]? {
        lock.lock()
        defer { lock.unlock() }
        return stringArrays[defaultName]
    }

    func set(_ value: [String], forKey defaultName: String) {
        lock.lock()
        defer { lock.unlock() }
        stringArrays[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        lock.lock()
        defer { lock.unlock() }
        stringArrays[defaultName] = nil
    }
}
