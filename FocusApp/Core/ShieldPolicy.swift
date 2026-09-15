import Foundation
import FamilyControls
import ManagedSettings

// Used by BOTH the app and monitor. Call under SharedStore's cross-process lock.
enum ShieldPolicy {
    private static let store = ManagedSettingsStore(named: .init(AppConstants.managedStore))

    static func apply(_ state: BlockingState) {
        let unlocked = state.grant?.selection ?? FamilyActivitySelection()
        let plan = ShieldSelection(
            apps: state.selection.applicationTokens, categories: state.selection.categoryTokens, domains: state.selection.webDomainTokens,
            unlockedApps: unlocked.applicationTokens, unlockedCategories: unlocked.categoryTokens, unlockedDomains: unlocked.webDomainTokens,
            activeGrant: state.hasTemporaryAccess
        )
        store.shield.applications = plan.applications.isEmpty ? nil : plan.applications
        store.shield.applicationCategories = plan.categories.isEmpty ? nil : .specific(plan.categories, except: plan.applicationExceptions)
        store.shield.webDomains = plan.domains.isEmpty ? nil : plan.domains
        store.shield.webDomainCategories = plan.categories.isEmpty ? nil : .specific(plan.categories, except: plan.domainExceptions)
        // New in 26.5: an inactive named store does not enforce its configuration.
        if #available(iOS 26.5, *) { store.isActive = true }
    }

    static func refreshTokens(in state: inout BlockingState) throws {
        guard #available(iOS 26.5, *) else { return }
        func refreshed(_ selection: FamilyActivitySelection) throws -> FamilyActivitySelection {
            var result = selection
            var apps = Array(selection.applicationTokens)
            var categories = Array(selection.categoryTokens)
            var domains = Array(selection.webDomainTokens)
            if !apps.isEmpty { try ManagedSettingsStore.refresh(&apps) }
            if !categories.isEmpty { try ManagedSettingsStore.refresh(&categories) }
            if !domains.isEmpty { try ManagedSettingsStore.refresh(&domains) }
            guard apps.count == selection.applicationTokens.count,
                  categories.count == selection.categoryTokens.count,
                  domains.count == selection.webDomainTokens.count else { throw ShieldError.expiredTokens }
            result.applicationTokens = Set(apps)
            result.categoryTokens = Set(categories)
            result.webDomainTokens = Set(domains)
            return result
        }
        // Work on copies; a partial refresh must never erase saved selections.
        let selection = try refreshed(state.selection)
        var grant = state.grant
        if let existing = grant {
            let unlocked = try refreshed(existing.selection)
            guard selection.contains(unlocked) else { throw ShieldError.expiredTokens }
            grant = UnlockGrant(id: existing.id, selection: unlocked, deadline: existing.deadline)
        }
        state.selection = selection
        state.grant = grant
    }
}

enum ShieldError: LocalizedError {
    case expiredTokens
    var errorDescription: String? { "Screen Time could not refresh the saved app selections. Protection could not be verified. Restore Screen Time permission and retry." }
}
