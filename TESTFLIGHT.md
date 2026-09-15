# LockIn TestFlight release

The supported release path is `scripts/release.py`. Do not archive in Xcode or drag an
unidentified `LockIn.ipa` into Transporter. The pipeline uses immutable, versioned
artifacts and will not upload anything during preparation.

## 1. One-time unattended signing setup

Create a **team** App Store Connect API key with the Developer role and access to
Certificates, Identifiers & Profiles. Download its `.p8` private key; Apple permits
that download only once. An individual API key cannot manage provisioning resources.

Install the key and machine-local configuration outside the repository:

```sh
python3 scripts/release.py bootstrap \
  --config "$LOCKIN_RELEASE_CONFIG" \
  --api-key-file "/path/to/AuthKey_KEYID.p8" \
  --api-key-id "KEYID" \
  --api-issuer-id "ISSUER_UUID" \
  --team-id "TEAMID" \
  --output-root "/Users/Shared/LockInReleases"
```

The bootstrap command copies the key with mode `0600`, writes the config with mode
`0600`, and refuses to overwrite either. Remove the original download after verifying
the installed copy and secure backup. Check readiness without contacting Apple:

```sh
python3 scripts/release.py credentials --config "$LOCKIN_RELEASE_CONFIG"
```

The first unattended archive attempts Xcode automatic signing with the API key and a
cloud-managed distribution certificate. If Apple does not permit cloud signing for
the team, import one distribution identity into a dedicated release keychain once;
subsequent runs remain unattended.

## 2. Apple Developer setup

Create these explicit App IDs in Certificates, Identifiers & Profiles:

- `com.dash1971.focusapp`
- `com.dash1971.focusapp.deviceactivity`
- `com.dash1971.focusapp.deviceactivityreport`
- `com.dash1971.focusapp.shieldconfiguration`
- `com.dash1971.focusapp.shieldaction`
- `com.dash1971.focusapp.widgets`

Create and enable the App Group:

- `group.com.dash1971.focusapp`

Attach all six App IDs to that App Group. Enable Family Controls for the app and the four Screen Time extensions; the widget needs only the App Group.

For TestFlight distribution, request Apple's Family Controls distribution entitlement for all five bundle IDs that use it. Development signing alone is not sufficient for an App Store Connect upload.

## 3. Prepare and validate a release

Set the version/build in source, commit it, merge it, and ensure `HEAD` is the exact
clean `origin/main` commit:

```sh
python3 scripts/release.py set-version --version 0.4.0 --build 8
```

Then run one command:

```sh
python3 scripts/release.py prepare --config "$LOCKIN_RELEASE_CONFIG"
```

Preparation performs, in order:

1. clean/exact-main, version, toolchain, credentials, and disk-space preflight;
2. core tests, simulator tests, and an unsigned device build;
3. complete bundle-layout and ExtensionKit metadata audit;
4. signed archive and App Store export;
5. signature, profile, entitlement, bundle ID, version, and SHA-256 audit; and
6. server-side Apple validation with `altool`.

It stops at `apple_validation_passed` and prints the immutable manifest, IPA, and
SHA-256. It does **not** upload.

After explicit approval of that exact hash, upload it:

```sh
python3 scripts/release.py upload \
  --config "$LOCKIN_RELEASE_CONFIG" \
  --manifest "/Users/Shared/LockInReleases/.../manifest.json" \
  --confirm-sha256 "THE_EXACT_64_CHARACTER_HASH"
```

The uploader rechecks the file hash, layout, signatures, profiles, and entitlements
immediately before upload. App Store Connect acceptance and build processing are
reported as separate states.

## 4. Physical-device acceptance matrix (required before release)

Use a harmless app. Test the oldest supported iOS version and the current release. Record device, OS, grant duration, expected/actual relock times, and pass/fail in the PR.

- [ ] Grant and deny/revoke Screen Time authorization; Restrictions must not imply protection without permission.
- [ ] Select an app: it shields immediately and remains shielded across app closure and overnight with no focus session or schedule.
- [ ] Test every unlock preset in order: 30 seconds; 1, 5, 10, 15, 25, 30 and 45 minutes; and 1 and 2 hours. Confirm there is no Custom choice and no duration above 2 hours.
- [ ] For each duration, leave LockIn, keep the unlocked app foregrounded, and measure actual automatic relock time.
- [ ] Repeat short-grant tests after force-quitting LockIn, with screen locked, in Low Power Mode, and after reboot. A grant must not remain available indefinitely; investigate any delay.
- [ ] Repeat across midnight, time-zone changes and manual clock changes. Reopening LockIn should expire inconsistent or elapsed grants.
- [ ] Set each wait duration; one Request access tap starts the countdown immediately, no second wait/final-unlock tap appears, and access is granted automatically only when the wait completes. Dismissing, switching targets or leaving LockIn cancels the wait.
- [ ] While restrictions are active, tap the settings gear and confirm the configured countdown starts immediately. Blocked apps and the wait duration must remain unavailable until it completes. Cancel/reopen must restart the full wait. With no active selection, settings may open directly.
- [ ] Confirm failed monitor registration leaves shields in place; use an injected failure/debugger if needed.
- [ ] Lock again early, then request a new grant. Old callbacks must not remove shields or cancel a still-valid new grant.
- [ ] Test individual apps, websites, categories and overlapping selections; other selected items remain shielded during a grant.
- [ ] Change selection during a grant: the grant ends, the replacement shields apply, and no stale callback restores the old selection.
- [ ] Upgrade an installed 0.2.1 build with an active session and enabled/disabled schedules. Confirm selection migration, new continuous blocking and removal of old named shields.
- [ ] Create/edit/delete a colored important calendar event. Navigate months and verify only the actual current date receives the today marker; selecting another month must not mark its first day as today.
- [ ] Create/rename/delete habits; toggle today and past cells in Daily, Weekly, Month and Yearly grids, relaunch, and verify saved preferences. Future completions must be disabled.
- [ ] Create/edit/delete notes with multiline and non-Latin text; verify Save, Cancel and relaunch persistence.
- [ ] Check the 2026 → 2027 progress on January 1 and December 31; it must appear above the dedicated Calendar and clamp outside 2026.
- [ ] Set the device display calendar to Japanese (and another non-Gregorian calendar) and confirm the 2026 / percentage / 2027 row still reports the correct Gregorian progress rather than 0%.
- [ ] Start, pause, resume and reset each countdown preset and a custom wheel duration. Switch sections and use fullscreen; elapsed time must remain deadline-based and the completion alert must fire at 00:00.
- [ ] Start, pause, resume and reset the stopwatch. Switch sections, background/foreground the app and use fullscreen; elapsed time must remain accurate.
- [ ] Create, edit, disable, re-enable and delete one-time and repeating alarms. Verify each weekday choice, foreground Stop, background notification Stop, sound and supported vibration with the device locked and the app force-quit.
- [ ] Open Mini Games from main navigation, allow/deny camera permission, and verify denial/unavailable states are handled. In a push-up position, confirm front-camera eye-level movement—not screen taps—controls the bird vertically; play until collision, restart, and return with Back.
- [ ] Verify Today's Activity shows real Unlocks, elapsed Unlock Time (including an active and early-ended grant), and total iPhone Screen Time including unrestricted apps. Recheck after a minute, after midnight and after relaunch.
- [ ] On iOS 26.5+, verify the shield says only “This app is blocked.” and Open LockIn launches LockIn while Close app exits the blocked app. On older supported iOS, record the platform-limited Open LockIn behavior and verify Close app still exits.
- [ ] Check widgets before/during/after access, old widget/deep links, neutral theme and new launcher icon.
- [ ] Check small/large iPhones, large Dynamic Type, VoiceOver and long names; verify all controls remain usable.

Device Activity callbacks are system-scheduled and can be delayed. A successful build or simulator test does not certify the requested real-time blocking behavior.

## 5. TestFlight activation

After the upload command succeeds, wait for App Store Connect processing, resolve any
compliance questions, and add the build to the intended internal TestFlight group.
“Uploaded” does not mean “processed” or “available to testers.”

## Release status

Opening or merging a PR does not sign, validate, upload, process, or release a build.
Those states exist only in a generated release manifest.

The default shield is persistent while individual Screen Time authorization remains enabled. Users can revoke authorization, uninstall the app, or deliberately remove selections. On every supported iOS version, close the shield and open LockIn manually to request access.
