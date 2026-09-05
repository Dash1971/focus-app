import Foundation
import FamilyControls
import ManagedSettings

// Shared by the app and monitor extension. Only this code writes the permanent
// store. The caller must hold SharedStore's transaction lock.
enum ShieldPolicy {
    static func apply(_ state: BlockingState) {
        let store = ManagedSettingsStore(named: .init(AppConstants.managedStore))
        let unlocked = state.grant.flatMap { $0.deadline.isActive() ? $0.selection : nil } ?? FamilyActivitySelection()
        let blocked = state.selection.subtracting(unlocked)
        store.shield.applications = blocked.applicationTokens.isEmpty ? nil : blocked.applicationTokens
        // An individually unlocked app also needs an exception from any blocked
        // categories it belongs to; subtracting the app token alone is not enough.
        store.shield.applicationCategories = blocked.categoryTokens.isEmpty ? nil : .specific(blocked.categoryTokens, except: unlocked.applicationTokens)
        store.shield.webDomains = blocked.webDomainTokens.isEmpty ? nil : blocked.webDomainTokens
        store.shield.webDomainCategories = blocked.categoryTokens.isEmpty ? nil : .specific(blocked.categoryTokens, except: unlocked.webDomainTokens)
    }
}
