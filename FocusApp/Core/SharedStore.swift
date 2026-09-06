import Foundation
import Darwin

// Atomic files + an advisory lock serialize app/extension transactions. Never
// fall back to standard defaults: it would silently separate their state.
final class SharedStore {
    static let shared = SharedStore()
    private let directory: URL?
    private let legacyDefaults: UserDefaults?

    init(directory: URL? = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroup),
         legacyDefaults: UserDefaults? = UserDefaults(suiteName: AppConstants.appGroup)) {
        self.directory = directory
        self.legacyDefaults = legacyDefaults
    }

    func load() throws -> BlockingState {
        try withLock { try read() }
    }

    @discardableResult
    func transaction(_ change: (inout BlockingState) throws -> Void,
                     afterSave: (BlockingState) -> Void = { _ in }) throws -> BlockingState {
        try withLock {
            var state = try read()
            try change(&state)
            try JSONEncoder().encode(state).write(to: stateURL(), options: .atomic)
            // Shields are updated under the same lock, so a stale extension
            // callback cannot overwrite a newer selection or temporary grant.
            afterSave(state)
            return state
        }
    }

    private func stateURL() throws -> URL {
        guard let directory else { throw StoreError.unavailable }
        return directory.appendingPathComponent("blocking-state.v2.json")
    }

    private func read() throws -> BlockingState {
        let url = try stateURL()
        if FileManager.default.fileExists(atPath: url.path) {
            return try JSONDecoder().decode(BlockingState.self, from: Data(contentsOf: url))
        }
        if let data = legacyDefaults?.data(forKey: "sharedSnapshot.v1") {
            return try JSONDecoder().decode(LegacySnapshot.self, from: data).migrated()
        }
        return BlockingState()
    }

    private func withLock<T>(_ operation: () throws -> T) throws -> T {
        guard let directory else { throw StoreError.unavailable }
        let descriptor = open(directory.appendingPathComponent("blocking-state.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw StoreError.unavailable }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw StoreError.unavailable }
        defer { flock(descriptor, LOCK_UN) }
        return try operation()
    }
}

enum StoreError: LocalizedError {
    case unavailable
    var errorDescription: String? { "LockIn could not access its shared storage. Check App Group signing and reopen the app. Your blocking settings have not been cleared." }
}
