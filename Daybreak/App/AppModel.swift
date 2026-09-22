import FamilyControls
import Foundation
import Observation

nonisolated enum SettingsError: LocalizedError {
    case startTooLate

    var errorDescription: String? {
        switch self {
        case .startTooLate:
            "Choose a start time before 11:45 PM. iOS needs at least 15 minutes before the day ends."
        }
    }
}

/// The app's single source of truth. Reads shared state once, keeps it in memory, and writes through on every change.
@Observable
final class AppModel {
    private(set) var authorization: ScreenTimeAuthorization = .notDetermined
    private(set) var selection = FamilyActivitySelection()
    private(set) var startTime: TimeOfDay = .defaultStart
    private(set) var isScheduleEnabled = false
    private(set) var strictness: Strictness = .standard
    private(set) var clearedDay: DayKey?
    private(set) var isOnboardingComplete = false
    private(set) var phase: ShieldPhase = .off
    private(set) var failedAttempts = 0

    /// The reflection being written. Views bind to it; `persistDraft()` writes it through.
    var draft = ReflectionDraft()

    let journal: JournalStore
    let gateway: any ScreenTimeGateway
    private let shared: SharedState

    init(gateway: any ScreenTimeGateway, shared: SharedState = SharedState(), journal: JournalStore = JournalStore()) {
        self.gateway = gateway
        self.shared = shared
        self.journal = journal
        load()
    }

    /// The real Screen Time gateway on a device; a mock in the Simulator, where shields and schedules do nothing.
    static func live() -> AppModel {
        if ProcessInfo.processInfo.arguments.contains("--reset-state") {
            SharedState().resetAll()
            try? FileManager.default.removeItem(at: JournalStore.fileURL())
            UserDefaults.standard.removeObject(forKey: MockScreenTimeGateway.persistedAuthorizationKey)
        }
        #if targetEnvironment(simulator)
        return AppModel(gateway: MockScreenTimeGateway())
        #else
        return AppModel(gateway: LiveScreenTimeGateway())
        #endif
    }

    private func load() {
        authorization = gateway.authorization
        selection = shared.selection ?? FamilyActivitySelection()
        startTime = shared.startTime
        isScheduleEnabled = shared.isScheduleEnabled
        strictness = shared.strictness
        clearedDay = shared.clearedDay
        isOnboardingComplete = shared.isOnboardingComplete
        if let data = shared.draftData, let saved = try? JSONDecoder().decode(ReflectionDraft.self, from: data) {
            draft = saved
        }
        phase = policy.phase(at: .now)
    }

    // MARK: - Derived state

    private var policy: ShieldPolicy {
        ShieldPolicy(startTime: startTime, isScheduleEnabled: isScheduleEnabled, clearedDay: clearedDay)
    }

    var todayKey: DayKey { DayKey(.now) }

    var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    var todayEntry: ReflectionEntry? { journal.entry(for: todayKey) }

    var streak: Int {
        JournalStreak.count(days: Set(journal.entries.map(\.day)), today: .now)
    }

    /// The most recent goals from a day other than today, for the "different from yesterday" check.
    var previousGoals: [String] {
        journal.entries.first { $0.day != todayKey }?.goals ?? []
    }

    var rubric: ReflectionRubric { ReflectionRubric(strictness: strictness) }

    func verdict(for draft: ReflectionDraft) -> RubricVerdict {
        rubric.evaluate(draft, previousGoals: previousGoals)
    }

    // MARK: - Lifecycle

    /// Recompute the phase for `now`, make sure the system still has the schedule, and make the shield match the policy.
    /// Called on launch, on every return to the foreground, and on a slow clock while Today is visible.
    func refresh(now: Date = .now) {
        authorization = gateway.authorization
        phase = policy.phase(at: now)
        guard authorization == .approved, isOnboardingComplete else { return }

        if isScheduleEnabled, !gateway.isScheduleRegistered {
            do {
                try gateway.startSchedule(at: startTime)
                Log.app.notice("Re-registered the daily schedule")
            } catch {
                Log.app.error("Could not register the schedule: \(error.localizedDescription, privacy: .public)")
            }
        }
        reconcileShield()
    }

    private func reconcileShield() {
        if phase.isShielded {
            gateway.applyShield(selection)
        } else {
            gateway.clearShield()
        }
    }

    func requestAuthorization() async {
        do {
            try await gateway.requestAuthorization()
        } catch {
            Log.app.error("Screen Time authorization failed: \(error.localizedDescription, privacy: .public)")
        }
        authorization = gateway.authorization
    }

    // MARK: - Settings

    func saveSelection(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        shared.selection = newSelection
        if phase.isShielded {
            gateway.applyShield(newSelection)
        }
    }

    func saveStartTime(_ time: TimeOfDay) throws {
        guard time.isAllowedStart else { throw SettingsError.startTooLate }
        startTime = time
        shared.startTime = time
        if isScheduleEnabled {
            gateway.stopSchedule()
            try gateway.startSchedule(at: time)
        }
        refresh()
    }

    func setScheduleEnabled(_ enabled: Bool) {
        isScheduleEnabled = enabled
        shared.isScheduleEnabled = enabled
        if enabled {
            do {
                try gateway.startSchedule(at: startTime)
            } catch {
                Log.app.error("Could not start the schedule: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            gateway.stopSchedule()
        }
        refresh()
    }

    func setStrictness(_ newValue: Strictness) {
        strictness = newValue
        shared.strictness = newValue
    }

    func completeOnboarding() {
        isOnboardingComplete = true
        shared.isOnboardingComplete = true
        setScheduleEnabled(true)
    }

    // MARK: - Reflection

    func persistDraft() {
        shared.draftData = draft.isEmpty ? nil : try? JSONEncoder().encode(draft)
    }

    /// Approve the current draft if it clears the bar. On success the entry is saved, today is cleared and the shield drops.
    @discardableResult
    func submitReflection(now: Date = .now) -> Bool {
        let verdict = verdict(for: draft)
        guard verdict.isApproved else {
            failedAttempts += 1
            return false
        }
        let entry = ReflectionEntry(
            id: UUID(),
            day: DayKey(now),
            approvedAt: now,
            goals: draft.filledGoals,
            reflection: draft.reflection.trimmingCharacters(in: .whitespacesAndNewlines),
            strictness: strictness,
            attempts: failedAttempts + 1
        )
        journal.append(entry)
        clearedDay = entry.day
        shared.clearedDay = entry.day
        draft = ReflectionDraft()
        persistDraft()
        failedAttempts = 0
        refresh(now: now)
        Log.app.notice("Reflection approved; shield cleared for \(entry.day.rawValue, privacy: .public)")
        return true
    }
}
