import FamilyControls
import ManagedSettings

/// Translates a selection into shield settings on a store, and clears them. Used by the app and the monitor extension.
nonisolated enum ShieldApplier {
    static func apply(_ selection: FamilyActivitySelection, to store: ManagedSettingsStore) {
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        let domains = selection.webDomainTokens

        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories, except: [])
        store.shield.webDomains = domains.isEmpty ? nil : domains
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories, except: [])
    }

    static func clear(_ store: ManagedSettingsStore) {
        store.clearAllSettings()
    }
}
