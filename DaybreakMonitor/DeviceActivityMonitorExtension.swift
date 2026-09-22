import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Woken by iOS at the start and end of the daily interval. Stays tiny on purpose: it runs under a strict memory limit.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == .daily else { return }

        let state = SharedState()
        let policy = ShieldPolicy(
            startTime: state.startTime,
            isScheduleEnabled: state.isScheduleEnabled,
            clearedDay: state.clearedDay)

        guard policy.shouldShield(at: .now) else {
            Log.monitor.notice("Interval started; today is already cleared or the schedule is off, so no shield")
            return
        }
        guard let selection = state.selection else {
            Log.monitor.error("Interval started but no selection is stored; nothing to shield")
            return
        }
        ShieldApplier.apply(selection, to: ManagedSettingsStore(named: .daily))
        Log.monitor.notice("Shield applied at interval start")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .daily else { return }
        ShieldApplier.clear(ManagedSettingsStore(named: .daily))
        Log.monitor.notice("Shield cleared at interval end")
    }
}
