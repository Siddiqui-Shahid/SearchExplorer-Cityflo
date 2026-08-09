import Foundation

/// Protocol-oriented seam over UserDefaults for persistence fakes/tests.
protocol KeyValueStoring: Sendable {
    func stringArray(forKey defaultName: String) -> [String]?
    func set(_ value: [String], forKey defaultName: String)
    func removeObject(forKey defaultName: String)
}

/// Thin Sendable wrapper so the store actor does not hold `UserDefaults` directly.
final class UserDefaultsKeyValueStore: KeyValueStoring, @unchecked Sendable {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func stringArray(forKey defaultName: String) -> [String]? {
        defaults.stringArray(forKey: defaultName)
    }

    func set(_ value: [String], forKey defaultName: String) {
        defaults.set(value, forKey: defaultName)
    }

    func removeObject(forKey defaultName: String) {
        defaults.removeObject(forKey: defaultName)
    }
}
