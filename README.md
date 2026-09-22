# Daybreak

An iOS app that shields the apps you choose from a start time each morning until you have written today's goals and a short reflection, and they clear a bar you set. Tap **Done reflecting** and the apps unlock until tomorrow's start time.

The full scope (PRD, user flow, wireframes, architecture) is in [`docs/blueprint.html`](docs/blueprint.html).

## Requirements

- Xcode 26.2 or later (Swift 6.2, iOS 17 SDK or later).
- A **paid** Apple Developer Program membership. The Family Controls entitlement is not available to free personal teams.
- A physical iPhone on iOS 17 or later to test shielding. The Simulator runs the whole UI through a mock gateway but cannot shield anything.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) to regenerate the project after editing `project.yml`.

## Build

```bash
xcodegen generate
open Daybreak.xcodeproj
```

Then, in Xcode:

1. Select your team under **Signing & Capabilities** for all four targets (Daybreak, DaybreakMonitor, DaybreakShield, DaybreakShieldAction), or set `DEVELOPMENT_TEAM` once in `project.yml` and regenerate.
2. With automatic signing, Xcode registers the **Family Controls (development)** capability and the app group `group.com.pranavgadiraju.daybreak` on each App ID. If it refuses, add both under Identifiers at developer.apple.com and retry.
3. Run the `Daybreak` scheme on your iPhone and accept the Screen Time prompt.

To rename the app or change the bundle identifier, edit `project.yml` (bundle ids, app group) and `Shared/AppGroup.swift` (the app group identifier must match the entitlements), then regenerate.

## Test

Unit tests (rubric, shield policy, day keys, streaks) and one end-to-end UI test (the first morning, on the mock gateway) run in the Simulator:

```bash
xcodebuild test -project Daybreak.xcodeproj -scheme Daybreak -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

First device test: set the start time two minutes ahead in Settings, background the app, wait, open a picked app and expect the Daybreak shield. Open Daybreak, write goals, tap **Done reflecting**, and expect the app to open. Reboot and expect it to stay open. Next morning, expect the shield back.

## How it works

- **Daybreak.app** (SwiftUI) handles authorization, the app picker, the schedule, the reflection form and the rubric, and writes shared state to the app group.
- **DaybreakMonitor** (`DeviceActivityMonitor`) is woken by iOS at the start and end of the daily interval and applies or clears the shield unless today is already cleared.
- **DaybreakShield** (`ShieldConfigurationDataSource`) supplies the shield's copy. **DaybreakShieldAction** (`ShieldActionDelegate`) closes the shielded app when its button is tapped.
- Shared state lives in the app group's `UserDefaults` suite; approved reflections live in `journal.json` in the app group container. Nothing leaves the device.

Before TestFlight or the App Store, request the Family Controls **distribution** entitlement from Apple; development builds do not need it.
