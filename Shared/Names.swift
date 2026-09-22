import DeviceActivity
import ManagedSettings

nonisolated extension DeviceActivityName {
    /// The single repeating daily interval: start time → 23:59.
    nonisolated static var daily: Self { Self("com.pranavgadiraju.daybreak.daily") }
}

nonisolated extension ManagedSettingsStore.Name {
    /// The one store both the app and the monitor extension write, so either side can clear what the other applied.
    nonisolated static var daily: Self { Self("com.pranavgadiraju.daybreak.daily") }
}
