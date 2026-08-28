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

## 3. Physical-device smoke test

Install directly from Xcode before uploading to TestFlight:

1. Accept Screen Time authorization.
2. Select one harmless test app.
3. Start a one-minute focus session and confirm the selected app is shielded.
4. Confirm the shield displays the end time.
5. Confirm the block clears after one minute while LockIn is not foregrounded.
6. Test a math-challenge unlock.
7. Test an emergency unlock and verify it appears in Progress.
8. Create a schedule beginning two minutes in the future and verify automatic activation and clearing.
9. Test an overnight schedule separately.
10. Run both timers with the phone locked and verify notifications.

## 4. TestFlight upload

1. In App Store Connect, create the LockIn app record using `com.dash1971.focusapp`.
2. In Xcode, select **Any iOS Device (arm64)**.
3. Choose **Product → Archive**.
4. Validate the archive in Organizer.
5. Distribute through **App Store Connect → Upload**.
6. Add the build to an internal TestFlight group.

## Known MVP boundaries

- Exercise, reading, cleaning, and custom challenges are honesty-confirmed. Math, question, and puzzle challenges are automatically verified.
- Emergency unlocks deliberately disable the active recurring schedule; the user must re-enable it afterward.
- Interval phase changes are reliable while the app is active. Notifications fire when it is backgrounded, but fully autonomous multi-phase background progression is planned for the next iteration.
- Apple's system owns the shield UI. LockIn controls the permitted text, colors, icon, and actions.
- On iOS 26.5 and later, the shield's challenge button can open LockIn directly. On iOS 18 through 26.4, Apple does not expose that action, so the user must open LockIn manually to complete the challenge.
