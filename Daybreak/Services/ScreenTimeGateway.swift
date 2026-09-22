import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import Observation

enum ScreenTimeAuthorization: Equatable {
    case notDetermined
    case denied
    case approved
}

/// Everything the app asks of Screen Time, behind one seam so the Simulator and previews can run the full UI.
protocol ScreenTimeGateway: AnyObject {
    var authorization: ScreenTimeAuthorization { get }
    var isScheduleRegistered: Bool { get }
    func requestAuthorization() async throws
    func applyShield(_ selection: FamilyActivitySelection)
    func clearShield()
    func startSchedule(at start: TimeOfDay) throws
    func stopSchedule()
}

/// The real thing. Only meaningful on a physical device with the Family Controls entitlement.
final class LiveScreenTimeGateway: ScreenTimeGateway {
    private let store = ManagedSettingsStore(named: .daily)
    private let activityCenter = DeviceActivityCenter()

    var authorization: ScreenTimeAuthorization {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .approved: .approved
        @unknown default: .notDetermined
        }
    }

    var isScheduleRegistered: Bool {
        activityCenter.activities.contains(.daily)
    }

    func requestAuthorization() async throws {
        try await Self.requestIndividualAuthorization()
    }

    /// `AuthorizationCenter` is not Sendable and its request runs off the caller's actor, so the call is made
    /// from a nonisolated context that fetches the shared instance itself instead of sending a main-actor-owned one.
    @concurrent
    private nonisolated static func requestIndividualAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }

    func applyShield(_ selection: FamilyActivitySelection) {
        ShieldApplier.apply(selection, to: store)
    }

    func clearShield() {
        ShieldApplier.clear(store)
    }

    func startSchedule(at start: TimeOfDay) throws {
        let schedule = DeviceActivitySchedule(
            intervalStart: start.components,
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        try activityCenter.startMonitoring(.daily, during: schedule)
    }

    func stopSchedule() {
        activityCenter.stopMonitoring([.daily])
    }
}

/// Stand-in for the Simulator and previews: remembers what it was asked to do and does nothing else.
/// Like the real center, it remembers a granted authorization across launches (in standard defaults).
@Observable
final class MockScreenTimeGateway: ScreenTimeGateway {
    static let persistedAuthorizationKey = "mock.authorizationApproved"

    var authorization: ScreenTimeAuthorization
    private(set) var isScheduleRegistered = false
    private(set) var isShieldActive = false
    private(set) var scheduledStart: TimeOfDay?
    var shouldDenyAuthorization = false

    init(authorization: ScreenTimeAuthorization? = nil) {
        if let authorization {
            self.authorization = authorization
        } else {
            self.authorization = UserDefaults.standard.bool(forKey: Self.persistedAuthorizationKey) ? .approved : .notDetermined
        }
    }

    func requestAuthorization() async throws {
        try await Task.sleep(for: .milliseconds(400))
        authorization = shouldDenyAuthorization ? .denied : .approved
        UserDefaults.standard.set(authorization == .approved, forKey: Self.persistedAuthorizationKey)
    }

    func applyShield(_ selection: FamilyActivitySelection) {
        isShieldActive = true
    }

    func clearShield() {
        isShieldActive = false
    }

    func startSchedule(at start: TimeOfDay) throws {
        scheduledStart = start
        isScheduleRegistered = true
    }

    func stopSchedule() {
        scheduledStart = nil
        isScheduleRegistered = false
    }
}
