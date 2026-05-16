import Foundation

/// Thin wrapper around NSUbiquitousKeyValueStore. Data ≤ 1MB.
final class CloudKVStore {
    private let key = "timebase.v1"
    private let store = NSUbiquitousKeyValueStore.default

    init() {
        store.synchronize()
    }

    func save(_ data: Data) {
        store.set(data, forKey: key)
        store.synchronize()
    }

    func load() -> Data? {
        store.data(forKey: key)
    }
}
