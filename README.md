# LockIn

A local-first iPhone app for keeping distractions locked and organizing everyday life.

**Locked by default → temporary access → locked again.**

## Version 0.4 next build

- Six directly accessible sections: Restrictions, Calendar, Habits, Notes, Timer and Mini Games.
- A focused Restrictions dashboard with real daily unlock count, elapsed unlock time and whole-device iPhone Screen Time. Active restrictions protect blocked-item and unlock-delay configuration until a real temporary grant is active. Waiting alone does not open settings.
- Calendar-only event management with a locale-safe Gregorian 2026 → 2027 progress bar and an independent real-date today marker.
- Card-based daily, weekly, monthly and yearly habit grids with individually editable day cells.
- Persistent countdown and stopwatch state, wheel-based custom countdown entry, six presets and a distraction-free fullscreen clock with an almost screen-filling display.
- One-time and weekday-repeat alarms backed by iOS local notifications, including sound, supported vibration and a Stop action when the app is not open.
- Flappy Bird Push-Up uses a full-opacity, natural-color front-camera preview for on-device nose tracking. The surrounding controls remain black/gray.
- Flappy difficulty increases smoothly with active play time (one level per 20 seconds), caps at level 50, and stays there indefinitely until collision. Nose loss pauses play; the score remains.
- Pushup Challenge is a separate two-player game on **one shared iPhone**: both players tap Ready, then take turns drawing a plain 1–3 or SKIP card. Done passes the turn; Give Up ends the game with the current player losing. No camera, networking, accounts or connection setup.
- The Restrictions activity card keeps live local unlock counters visible independently of Apple's Total Screen Time report. Missing report data shows “—”, not an invented zero. Short unlocks display seconds; finished grants use observed relock time.
- A minimal blocked-app shield with Open LockIn and Close app actions. Opening the parent controls app directly from a shield requires iOS 26.5 or newer; earlier iOS versions keep the shield in place when Open LockIn is tapped because Apple exposes no parent-app launch response there.

Notification permission is required for countdowns and alarms to alert while LockIn is not active. Delivery, sound and vibration remain subject to iOS notification, Focus and device-sound settings.

## Version 0.3 blocking redesign

- Selected apps, categories and websites stay shielded continuously while Screen Time authorization remains enabled.
- Requesting Temporary Unlock immediately starts the configured wait (None, 10, 20, 30, 45 or 60 seconds). After the wait, app selection and the duration wheel appear automatically. Select one or more blocked items and tap Unlock selected apps. None opens that selection flow immediately; it never bypasses the settings lock. Leaving the app or dismissing the unlock screen cancels the request.
- A wheel picker offers exactly 30 seconds; 1, 5, 10, 15, 25, 30 and 45 minutes; and 1 or 2 hours. One temporary grant at a time; other selected items remain blocked. The duration choices are enforced in the model as well as the wheel.
- A permanent dark theme with black, charcoal and gray surfaces and the supplied lock-and-arms icon.
- Monthly calendar with named, colored events and important dates.
- Habits with day, week, month and year views, period navigation and editable past completions.
- Simple local notes with explicit Save, edit and delete actions.
- A date-driven 2026 → 2027 progress bar above the Calendar.
- No focus sessions or user blocking schedules. Mini games are independent of restrictions; the only Restrictions activity figures are the requested daily unlock count, unlock time and Total Screen Time.

## Blocking semantics and limits

A category grants access to the category as a whole. An app or website also selected individually still needs its own unlock. Individually unlocked apps/websites are excluded from category shielding while their grant is active. Initial app selection activates native restrictions immediately. Afterwards, settings can be edited only during actual temporary access; the save operation rechecks the current grant under the shared lock. Removing an item then makes it available, and applying a new selection ends the current grant.

Managed Settings holds the default shields. Before granting temporary access, LockIn registers a **one-time internal Device Activity interval starting at the relock deadline**, lasting 16 minutes. The monitor restores shields at `intervalDidStart`; `intervalDidEnd` is a backup. This avoids registering a sub-15-minute interval for short unlocks. These are implementation timers, not user blocking schedules. Foreground expiration and reopen reconciliation also restore shields. An internal daily recovery monitor reapplies saved shields when iOS wakes the extension. It does not expose user scheduling. Missing relock monitoring cancels a saved grant on reopen. iOS 26.5+ refreshes stored Screen Time tokens and explicitly activates the named store; older systems retain native shielding without those newer APIs. Shared blocking data is accessible after the first device unlock following reboot, including while the screen is subsequently locked.

**Device Activity is controlled by iOS, not a real-time timer guarantee.** Short unlocks, force-quit, reboot, locked-screen, activity-report refresh and clock/time-zone behavior require the physical-device tests in [TESTFLIGHT.md](TESTFLIGHT.md). Clock/reboot detection takes effect when the app or monitor next runs. Permission revocation or uninstalling LockIn can disable protection; this is individual Screen Time authorization, not tamper-proof device management. Widgets show saved intent, not proof of current system enforcement.

The shield's Close app action works on every supported iOS version. Open LockIn uses Apple's parent-controls-app response on iOS 26.5 and newer; older supported releases do not provide an extension API that can launch the parent app.

## Upgrade from 0.2.1

On first launch, preserve the global selection plus selections from the former active session and enabled schedules. Apply permanent shields before clearing old named stores and stopping old monitoring. Retain the old defaults snapshot as a rollback copy, but do not display or continue its challenges, schedules or analytics. Existing users should review their blocked selection because formerly scheduled items now stay blocked continuously.

## Project and validation

- `FocusApp/`: SwiftUI application, policies and persistence.
- `Extensions/`: relock monitor, daily Screen Time report, shield appearance/actions, and widgets.
- `FocusAppTests/`: date, deadline, persistence and migration regressions.
- `Package.swift`: Foundation-only tests runnable with `swift test` without an iOS SDK.
- `.github/workflows/ios.yml`: core tests, unsigned iPhone build and simulator tests.
- `docs/AUDIT.md`: audit findings, design choices and review risks.

Requires iOS 18+, full Xcode 26+ for app builds, App Group signing, and Apple's Family Controls capability. Physical-device Screen Time testing and distribution approval are required before TestFlight. See [TESTFLIGHT.md](TESTFLIGHT.md).

Regenerate the project with `ruby scripts/generate_xcodeproj.rb` after installing the `xcodeproj` gem. Run `swift scripts/generate_app_icon.swift` from the repository root to package the original artwork into the opaque 1024×1024 PNG asset.

## Privacy

No accounts, servers, analytics, advertising or network dependencies. Screen Time tokens, bounded unlock history and temporary grants live in the shared App Group container. A file lock and atomic writes serialize app/extension transactions. Front-camera frames used for nose landmark detection stay on-device and are neither saved nor transmitted. Notes, habits and calendar events live separately in the app's Application Support directory. Events are local civil dates; no Calendar permission or external calendar sync is used. Unreadable saved data produces an error rather than silently replacing it with empty state.

MIT License. See [LICENSE](LICENSE).
