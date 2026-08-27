import Foundation
import FamilyControls

final class SharedStore {
    static let shared = SharedStore()

    private let defaults: UserDefaults
    private let key = "sharedSnapshot.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: AppConstants.appGroup) ?? .standard
    }

    func load() -> SharedSnapshot {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? decoder.decode(SharedSnapshot.self, from: data) else {
            return SharedSnapshot()
        }
        return snapshot
    }

    func save(_ snapshot: SharedSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    func mutate(_ change: (inout SharedSnapshot) -> Void) {
        var snapshot = load()
        change(&snapshot)
        save(snapshot)
    }
}
