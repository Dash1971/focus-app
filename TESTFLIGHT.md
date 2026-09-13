# LockIn TestFlight checklist

## 1. Apple Developer setup

Create these explicit App IDs in Certificates, Identifiers & Profiles:

- `com.dash1971.focusapp`
- `com.dash1971.focusapp.deviceactivity`
- `com.dash1971.focusapp.shieldconfiguration`
- `com.dash1971.focusapp.shieldaction`
- `com.dash1971.focusapp.widgets`

Create and enable the App Group:

- `group.com.dash1971.focusapp`

Attach all five App IDs to that App Group. Enable Family Controls for the app and the three Screen Time extensions; the widget needs only the App Group.

For TestFlight distribution, request Apple's Family Controls distribution entitlement for all four bundle IDs. Development signing alone is not sufficient for an App Store Connect upload.

## 2. Xcode signing

1. Open `FocusApp.xcodeproj` with full Xcode.
2. Select the `FocusApp` project and set the same Apple Developer Team for the app and all four extensions.
3. Keep automatic signing enabled.
4. Confirm the app and Screen Time targets show Family Controls and App Groups; confirm the widget target shows App Groups.
5. Confirm the App Group is `group.com.dash1971.focusapp` for all targets.

If the project file needs regeneration, install the Ruby `xcodeproj` gem and run:

```sh
gem install --user-install xcodeproj --no-document
ruby scripts/generate_xcodeproj.rb
```

## 3. Physical-device acceptance matrix (required before release)

Use a harmless app. Test the oldest supported iOS version and the current release. Record device, OS, grant duration, expected/actual relock times, and pass/fail in the PR.

- [ ] Grant and deny/revoke Screen Time authorization; Restrictions must not imply protection without permission.
- [ ] Select an app: it shields immediately and remains shielded across app closure and overnight with no focus session or schedule.
- [ ] Test every preset: 30 seconds, 1, 5, 10, 15, 25 and 30 minutes; test custom 1 and 1,440 minutes.
- [ ] For each duration, leave LockIn, keep the unlocked app foregrounded, and measure actual automatic relock time.
- [ ] Repeat short-grant tests after force-quitting LockIn, with screen locked, in Low Power Mode, and after reboot. A grant must not remain available indefinitely; investigate any delay.
- [ ] Repeat across midnight, time-zone changes and manual clock changes. Reopening LockIn should expire inconsistent or elapsed grants.
- [ ] Set each wait duration; no access before the wait AND final Unlock tap. Dismissing, switching targets or leaving LockIn cancels the wait.
- [ ] Confirm failed monitor registration leaves shields in place; use an injected failure/debugger if needed.
- [ ] Lock again early, then request a new grant. Old callbacks must not remove shields or cancel a still-valid new grant.
- [ ] Test individual apps, websites, categories and overlapping selections; other selected items remain shielded during a grant.
- [ ] Change selection during a grant: the grant ends, the replacement shields apply, and no stale callback restores the old selection.
- [ ] Upgrade an installed 0.2.1 build with an active session and enabled/disabled schedules. Confirm selection migration, new continuous blocking and removal of old named shields.
- [ ] Create/edit/delete a colored important calendar event. Navigate months and verify only the actual current date receives the today marker; selecting another month must not mark its first day as today.
- [ ] Create/rename/delete habits; toggle today and past cells in Daily, Weekly, Month and Yearly grids, relaunch, and verify saved preferences. Future completions must be disabled.
- [ ] Create/edit/delete notes with multiline and non-Latin text; verify Save, Cancel and relaunch persistence.
- [ ] Check the 2026 → 2027 progress on January 1 and December 31; it must appear above the dedicated Calendar and clamp outside 2026.
- [ ] Start, pause, resume and reset each countdown preset and a custom wheel duration. Switch sections and use fullscreen; elapsed time must remain deadline-based and the completion alert must fire at 00:00.
- [ ] Start, pause, resume and reset the stopwatch. Switch sections, background/foreground the app and use fullscreen; elapsed time must remain accurate.
- [ ] Create, edit, disable, re-enable and delete one-time and repeating alarms. Verify each weekday choice, foreground Stop, background notification Stop, sound and supported vibration with the device locked and the app force-quit.
- [ ] Open Mini Games from main navigation, play/restart Flappy Bird Push-Up, return with Back, and verify every main section remains directly reachable on small and large iPhones.
- [ ] Check widgets before/during/after access, old widget/deep links, neutral theme and new launcher icon.
- [ ] Check small/large iPhones, large Dynamic Type, VoiceOver and long names; verify all controls remain usable.

Device Activity callbacks are system-scheduled and can be delayed. A successful build or simulator test does not certify the requested real-time blocking behavior.

## 4. TestFlight upload

1. In App Store Connect, create the LockIn app record using `com.dash1971.focusapp`.
2. In Xcode, select **Any iOS Device (arm64)**.
3. Choose **Product → Archive**.
4. Validate the archive in Organizer.
5. Distribute through **App Store Connect → Upload**.
6. Add the build to an internal TestFlight group.

## Release status

This redesign needs the acceptance matrix above before release. The PR documents automated validation separately. No App Store upload, distribution signing or device test is implied by opening the PR.

The default shield is persistent while individual Screen Time authorization remains enabled. Users can revoke authorization, uninstall the app, or deliberately remove selections. On every supported iOS version, close the shield and open LockIn manually to request access.
