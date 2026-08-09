import XCTest
@testable import SearchExplorer

final class RecentSearchesStoreTests: XCTestCase {
    private var storage: InMemoryKeyValueStore!
    private var store: RecentSearchesStore!

    override func setUp() async throws {
        storage = InMemoryKeyValueStore()
        store = RecentSearchesStore(storage: storage, key: "test.recents", limit: 3)
    }

    func testRecordDedupesCaseInsensitivelyAndMovesToFront() async {
        _ = await store.record("Swift")
        _ = await store.record("Combine")
        let items = await store.record("swift")

        XCTAssertEqual(items, ["swift", "Combine"])
    }

    func testRecordRespectsLimit() async {
        _ = await store.record("one")
        _ = await store.record("two")
        _ = await store.record("three")
        let items = await store.record("four")

        XCTAssertEqual(items, ["four", "three", "two"])
    }

    func testClearRemovesPersistedValues() async {
        _ = await store.record("keep")
        await store.clear()
        let items = await store.load()
        XCTAssertTrue(items.isEmpty)
    }

    func testEmptyOrWhitespaceQueryDoesNotMutate() async {
        _ = await store.record("solid")
        let after = await store.record("   ")
        XCTAssertEqual(after, ["solid"])
    }
}
