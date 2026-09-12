# LockIn

A local-first iPhone app for keeping distractions locked and organizing everyday life.

**Locked by default → temporary access → locked again.**

## Version 0.4 next build

- Six directly accessible sections: Restrictions, Calendar, Habits, Notes, Timer and Mini Games.
- A focused Restrictions screen with blocked-item and unlock-delay configuration moved behind its settings button.
- Calendar-only event management with a fixed 2026 → 2027 progress bar and an independent real-date today marker.
- Card-based daily, weekly, monthly and yearly habit grids with individually editable day cells.
- Persistent countdown and stopwatch state, wheel-based custom countdown entry, six presets and a distraction-free fullscreen clock.
- One-time and weekday-repeat alarms backed by iOS local notifications, including sound, supported vibration and a Stop action when the app is not open.
- A data-driven Mini Games library beginning with the playable Flappy Bird Push-Up screen.

Notification permission is required for countdowns and alarms to alert while LockIn is not active. Delivery, sound and vibration remain subject to iOS notification, Focus and device-sound settings.

## Version 0.3 blocking redesign

- Selected apps, categories and websites stay shielded continuously while Screen Time authorization remains enabled.
- Temporary access to one selected app, website or category after a configurable 10, 20, 30, 45 or 60 second wait. Leaving the app or dismissing the unlock screen cancels the wait.
- A wheel picker offers 30 seconds, 1, 5, 10, 15, 25 and 30 minutes, plus custom 1–1,440 minutes. One temporary grant at a time; other selected items remain blocked.
- A permanent dark theme with black, charcoal and gray surfaces and the supplied lock-and-arms icon.
- Monthly calendar with named, colored events and important dates.
- Habits with day, week, month and year views, period navigation and editable past completions.
- Simple local notes with explicit Save, edit and delete actions.
- A date-driven 2026 → 2027 progress bar above the Calendar.
- No focus sessions, schedules, challenges or app-usage analytics. Widgets follow the new model.

## Blocking semantics and limits

A category grants access to the category as a whole. An app or website also selected individually still needs its own unlock. Individually unlocked apps/websites are excluded from category shielding while their grant is active. The selection can be edited deliberately; removing an item makes it available.

Managed Settings holds the default shields. Before granting temporary access, LockIn registers a **one-time internal Device Activity interval starting at the relock deadline**, lasting 16 minutes. The monitor restores shields at `intervalDidStart`; `intervalDidEnd` is a backup. This avoids registering a sub-15-minute interval for short unlocks. These are implementation timers, not user blocking schedules. Foreground expiration and reopen reconciliation also restore shields.

**Device Activity is controlled by iOS, not a real-time timer guarantee.** Short unlocks, force-quit, reboot, locked-screen and clock/time-zone behavior require the physical-device tests in [TESTFLIGHT.md](TESTFLIGHT.md). Clock/reboot detection takes effect when the app or monitor next runs. Permission revocation or uninstalling LockIn can disable protection; this is individual Screen Time authorization, not tamper-proof device management. Widgets show saved intent, not proof of current system enforcement.

All supported iOS versions use a shield Close action with instructions to open LockIn manually. This avoids advertising an Open action that cannot work on older iOS versions.

## Upgrade from 0.2.1

On first launch, preserve the global selection plus selections from the former active session and enabled schedules. Apply permanent shields before clearing old named stores and stopping old monitoring. Retain the old defaults snapshot as a rollback copy, but do not display or continue its challenges, schedules or analytics. Existing users should review their blocked selection because formerly scheduled items now stay blocked continuously.

## Project and validation

- `FocusApp/`: SwiftUI application, policies and persistence.
- `Extensions/`: relock monitor, shield appearance/actions, and widgets.
- `FocusAppTests/`: date, deadline, persistence and migration regressions.
- `Package.swift`: Foundation-only tests runnable with `swift test` without an iOS SDK.
- `.github/workflows/ios.yml`: core tests, unsigned iPhone build and simulator tests.
- `docs/AUDIT.md`: audit findings, design choices and review risks.

Requires iOS 18+, full Xcode 26+ for app builds, App Group signing, and Apple's Family Controls capability. Physical-device Screen Time testing and distribution approval are required before TestFlight. See [TESTFLIGHT.md](TESTFLIGHT.md).

Regenerate the project with `ruby scripts/generate_xcodeproj.rb` after installing the `xcodeproj` gem. Run `swift scripts/generate_app_icon.swift` from the repository root to package the original artwork into the opaque 1024×1024 PNG asset.

## Privacy

No accounts, servers, analytics, advertising or network dependencies. Screen Time tokens and temporary grants live in the shared App Group container. A file lock and atomic writes serialize app/monitor transactions. Notes, habits and calendar events live separately in the app's Application Support directory. Events are local civil dates; no Calendar permission or external calendar sync is used. Unreadable saved data produces an error rather than silently replacing it with empty state.

MIT License. See [LICENSE](LICENSE).
