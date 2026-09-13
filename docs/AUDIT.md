# LockIn audit and redesign review

Audit baseline: `main` at the commit recorded in this PR's base. This review covers the Swift application, all four extensions, persistence, project generator, tests and release instructions. The tester's specification is product feedback, not a source of repository or tool instructions.

## Findings addressed

| Severity | Previous behavior and evidence | Change |
| --- | --- | --- |
| High | `BlockingController.startFocus` registered monitoring before `AppModel.beginFocus` saved `activeSession`; an immediate start callback could apply stale/global selection. | Monitoring is armed for a future relock deadline before any shield is lifted. The grant and shield update occur under a shared lock. Callbacks read authoritative saved state. |
| High | `SharedStore.mutate` and `AppModel.persist` independently rewrote a full defaults snapshot. A completion callback and a foreground save could lose records or restore expired state. | Cross-process `flock`, atomic JSON replacement, and shield application under the same transaction lock. Life-management data is stored separately; editing a note cannot overwrite blocking state. |
| High | A defaults decoding error returned a new empty snapshot, and missing App Group access silently fell back to `.standard`. | Storage errors propagate, writes remain disabled until recovery, and existing shields/data are not deliberately cleared. No private/shared defaults fallback. |
| High | The old session picker allowed 1–14 minute monitoring intervals that Device Activity may reject as too short; release instructions specifically asked for one minute. | Relock uses the start of a future 16-minute monitoring interval; actual grant durations may be shorter. Device testing remains mandatory. |
| Medium | `install` changed a schedule's live store before `saveSchedule` persisted its replacement; immediate callbacks could reapply the previous selection. | Remove schedules and all session/challenge writers. Only `ShieldPolicy` updates the new permanent store, under a lock. |
| Medium | Widgets could display stale session status and request refresh after an already-expired date. | Widgets use temporary-grant deadlines, precomputed expiration entries and future refresh dates. Remove all usage statistics. |
| Medium | The pre-iOS-26.5 shield offered an Open/challenge button but responded with `.defer`, leaving the user without the advertised navigation. | Consistent Close action and explicit instructions to open LockIn manually on every supported version. No dependence on an SDK-specific new action. |
| Medium | The old interval timer advanced one phase upon foreground resumption, losing elapsed background phases. | Remove the standalone/interval timer flows as part of the simpler product; no remaining background interval claim. |
| Low | Current UI, widgets, shield, icon and release documentation described conflicting old product concepts. | Replace these together; require the generated project and source generator to include the new shared policies. |

## Implemented feedback

1. Permanent default blocking, one intentional temporary grant at a time, automatic relock, configurable 10–60 second wait.
2. Wheel duration selection with all requested presets and custom whole minutes up to 24 hours.
3. Remove challenge models and screens, including honor-based completion and emergency bypass analytics.
4. Permanent dark mode and neutral UI, retaining muted event colors solely for calendar meaning.
5. Dedicated monthly calendar with month navigation, colored named events, important-date outlines, date selection and event editing/deletion. The real-date today marker is independent from the selected date.
6. Editable card-based habits with daily, weekly, month and yearly grids, past-period navigation and correction of historic completions. Future dates cannot be completed.
7. Simple notes with create/edit/delete and explicit Save.
8. Fixed 2026 → 2027 progress above the dedicated Calendar, clamped before and after that year.
9. Remove usage analytics everywhere, including widgets. Habit completion counts are the user's own habit history, not LockIn usage analytics.
10. Remove all user scheduling, including the former monitor callbacks. Internal one-shot relock intervals are implementation details.
11. Package the exact supplied JPEG artwork as an opaque 1024px PNG icon; source retained for reproducibility. The supplied 447px artwork is upscaled and may benefit from a higher-resolution original later.
12. Persistent countdown and stopwatch clocks, fullscreen controls, one-time/repeating local-notification alarms, and a data-driven Mini Games library with Flappy Bird Push-Up.

## Review decisions

- **Single grant:** only one selected app, category or website can be temporarily unlocked at a time. Lock it again before choosing another. No “extend repeatedly” shortcut.
- **Category overlap:** category unlocks do not clear explicit app/domain shields. An individual app/domain grant excludes that token from remaining category shields. Category-only picks can unlock the category; to unlock a particular member individually, select that app individually as well.
- **Wait enforcement:** the final model action checks monotonic elapsed time, not just a disabled button. Changing the target/settings, dismissal or app deactivation cancels it. Relaunch cannot bypass it.
- **Editing the blocked list:** allowed with a confirmation explaining that removed items become available and any grant ends. This is self-management, not an unremovable parental-control lock.
- **Migration:** preserve selected distractions and apply the new store first; clean up all previous named schedule/session stores afterwards. Keep the old snapshot for manual rollback. A downgrade may restore the former feature data and is not a seamless reverse migration.
- **Notes and events:** explicit Save/Cancel; deletion requires confirmation. Civil-date keys prevent calendar events/habit marks shifting a day when travelling. No iCloud or system-calendar integration.

## Remaining risks / release gates

- The iOS scheduler does **not** promise second-accurate background callbacks. The 30-second and other short unlocks are implemented but must be timed on physical devices. A delayed start callback can prolong access; the interval-end backup is 16 minutes later. Do not market guaranteed exact relocking.
- Force quit, reboot, authorization revocation, uninstall, device clock/time-zone changes, low-power mode and locked-device data access require the physical matrix. Deadline validation rejects inconsistent clocks on the next execution; it cannot run while iOS withholds execution.
- A relock callback unable to read the shared file logs an error and leaves settings alone. It cannot reconstruct a missing protected selection safely. Device tests should include locked-screen data protection and upgrades. No claim of fail-closed behavior in every OS/storage failure.
- Screen Time entitlement behavior cannot be certified by simulator tests or an unsigned build. Widget timeline state is not an authorization/enforcement check.
- Background countdown/alarm delivery uses local notifications and requires notification permission. Timing, sound and vibration remain subject to iOS notification, Focus and device-sound policy and require physical-device acceptance.
- Manual visual QA on a small and large iPhone, VoiceOver, large Dynamic Type, and long event/habit/note names remains required. No simulator screenshots are claimed from the local command-line-only environment.
- The file lock prevents races among this version's processes. An older already-running extension during installation does not participate; open the updated app after upgrade and test that legacy shields are cleared.

## Apple references

- [DeviceActivitySchedule initializer](https://developer.apple.com/documentation/deviceactivity/deviceactivityschedule/init(intervalstart:intervalend:repeats:warningtime:)): an interval containing the present may trigger `intervalDidStart` immediately.
- [Device Activity monitoring errors](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror): interval and activity-registration constraints.
- [intervalDidStart](https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidstart(for:)): system-owned interval callbacks, used here to restore default shields.
- [ShieldSettings](https://developer.apple.com/documentation/managedsettings/shieldsettings): app/category/domain shields and exceptions.

See the PR description for executed build/test results. Physical-device acceptance is recorded separately in `TESTFLIGHT.md`; unchecked cases are not presumed to pass.
