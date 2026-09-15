# Camera, Pushup Challenge and Restrictions follow-up

Base: `4accb12` on main. This PR follows the user's clarification that **both players share one iPhone**. It does not add network multiplayer, Game Center, new entitlements or permission prompts.

## What changed

- Remove the camera preview's `.grayscale(1)` and `.opacity(0.2)`. Live camera pixels keep natural color and brightness. A small dark score capsule maintains text contrast without dimming the entire image. Camera lighting, permission and tracking still need a real front-camera test.
- Add Pushup Challenge to Mini Games. Both players mark themselves ready on the shared phone. Player 1 begins; the active player draws exactly one card, completes the pushups, and taps Done to pass. Give Up is a separate button and clearly belongs to the displayed current player; the first accepted Give Up ends the match. Replay resets the game.
- The card face is black with a one-point white outline and only the centered number or SKIP. The undrawn card is blank; the draw instruction is outside it. Each draw samples uniformly from 1, 2, 3 and SKIP (25% each). SKIP stays visible until Done passes the turn, with no pushups required. This avoids an easily missed automatic skip.
- Pure game rules reject Done before drawing, repeat draws, wrong-player actions, stale taps and changes after a result. No game code reads or mutates blocking state, temporary grants, challenges or camera data. There is one local state shared by both people looking at the same screen.
- Keep the existing minimalist Restrictions layout: Today’s Activity beneath the title, one rounded three-column card, settings off the dashboard, and the main access action near the bottom. No large lock/status block or restricted-app list is introduced.
- Read Unlocks and Unlock Time directly from app-owned saved grant records, updated every second. The Apple report now renders only Total Screen Time; the report sandbox no longer silently replaces failed shared-file reads with zero unlocks. Missing storage/report data is shown as unavailable.
- Use the current user's iPhone activity with no app, category or website filter, including unrestricted apps. Refresh the report request each minute and at the day boundary. iOS controls report availability/latency; this is not a second-by-second usage API. When iCloud shares activity across multiple iPhones, the API's iPhone device-class filter can include those devices; it does not offer this app a stable current-device-ID filter.
- Split grant durations at midnight, exclude future starts, display sub-minute access in seconds, and record an observed relock time rather than always capping completed grants to their planned deadline. Historical records already written with a capped end cannot be reconstructed. Unlock Time measures elapsed access granted, not time actually spent inside a particular app.

## Automated checks

The PR's CI runs pure game/date/time tests, simulator storage/stat regressions, the unsigned app + extensions build, Device Activity Report ExtensionKit packaging validation and release-pipeline checks. The existing release version/build metadata is retained for the maintainer's release process. No merge, signing, build distribution or TestFlight upload is performed by this PR.

## Maintainer's device/visual checks before building for testers

- In Flappy Bird Push-Up, verify natural-color preview at normal brightness under normal indoor lighting, with dark surrounding controls. Check tracking, restarting and denied camera permission.
- On one iPhone, confirm Player 2 cannot start play alone; mark both ready. Draw numeric and SKIP cards, verify they remain visible, verify Done passes exactly one turn, and give up on each player's turn. Verify only the first result wins and Play again clears all state.
- Confirm Pushup Challenge never requests camera/local network permissions or changes restrictions/access. Leave and reopen it; a new match starts.
- Check card legibility, button separation, large text and VoiceOver. There is no independently connected second device or remote game state to test.
- Use a 30-second unlock and an early relock; compare count and elapsed time, including an observed delayed relock. Test across midnight. Deny/revoke Screen Time permission and confirm no synthetic Screen Time value appears.
- Use an unrestricted app, return to Restrictions, and allow the OS report to refresh. Verify Total Screen Time includes that usage. Check small iPhones and long/large labels for the single three-column card. Unlocks/time should remain visible even if the Apple report is loading or unavailable.

## Apple references

- [DeviceActivityFilter](https://developer.apple.com/documentation/deviceactivity/deviceactivityfilter) supports current-user reports and application/category/domain filtering.
- [Filter initializer](https://developer.apple.com/documentation/deviceactivity/deviceactivityfilter/init(segment:users:devices:applications:categories:webdomains:)) explains that omitting the three token filters requests all device activity.
- [Segment totalActivityDuration](https://developer.apple.com/documentation/deviceactivity/deviceactivitydata/activitysegment/totalactivityduration) is the system's screen-on duration for the segment.

## Additional requirements added during this PR

### Native app blocking and access policy

The source already called Managed Settings; there was no evidence of a fake overlay replacing the native API. The tester's specific failure has **not** been reproduced on a physical device here. This patch addresses concrete gaps instead of claiming an unverified root cause:

- Persist and apply the native application/category/domain shield plan directly when the initial selection is activated. The same policy runs in the monitor extension. Unselected grants do not clear unrelated shields.
- Explicitly activate the named store and refresh expired Screen Time tokens on iOS 26.5+, both on foreground reconciliation and extension recovery. A failed refresh does not erase saved selections; it ends temporary access, attempts full saved shields, and surfaces/logs the failure. Older supported iOS versions cannot use the 26.5 refresh API. Tokens voided by revoked authorization may need user repair; revocation cannot be prevented under individual authorization.
- Add an internal daily recovery monitor, which restores saved shields when iOS invokes it. It is not a user blocking schedule or an exact background timer guarantee. Reopening with a missing relock monitor cancels the grant immediately. Blocked-state file and lock use after-first-unlock data protection on iOS to support a monitor invocation while the screen is locked.
- Existing selected apps and restrictions survive app restart; permanent shields are never cleared merely because the app closes. Reboot and OS-delayed callbacks require the physical checks below; the app cannot force iOS to launch an extension before its first device unlock.
- Settings access requires **an active grant containing selected items**, not an elapsed wait or a retained UI flag. Recheck under the shared transaction lock when saving the app selection or waiting time. A picker left open past expiry cannot save; applying a new selection ends the grant and reapplies full restrictions.
- Temporary Unlock starts its countdown on presentation. It then automatically shows multi-selection and the scrolling duration picker. None means zero wait/no countdown. It does not create a grant and cannot open settings by itself.
- Preserve exactly 30 sec; 1, 5, 10, 15, 25, 30, 45 min; 1 hour; 2 hours. No Custom and no duration above two hours. Selection is limited to previously blocked items; one grant may cover multiple chosen items.

### Nose-controlled Flappy Bird

Replace the eye tracker with the nose contour's vertical center. Face bounds only convert the landmark coordinates; eyes and head center do not drive the bird. Explicitly rotate/mirror capture buffers and preview together and feed upright buffers to Vision. Use automatic exposure and white balance with no grayscale/dimming. Serial configuration/frame/shutdown and request identities prevent a delayed camera permission response from starting capture after leaving the game.

A time-based 60ms smoothing filter reduces jitter without the old heavy lag; brief loss is tolerated, sustained nose loss pauses play. Speed, gap size and spawn interval change continuously over active play time. The displayed level rises every 20 seconds through level 50; all difficulty values cap at that point and the game continues. Existing pipes retain their spawned gap dimensions. Backgrounding pauses gameplay and stops capture.

### Required physical end-to-end test (not executed here)

Use a signed build with approved Family Controls and matching App Group entitlements, and record iOS version/build and actual results:

1. Allow Screen Time, choose a harmless app, and confirm **Activate Restrictions**. Open that other app and verify the system shield appears.
2. Close/reopen LockIn, then restart the phone and unlock it once. Verify the chosen app is still protected. Verify permission revocation is reported rather than falsely presented as enforced protection.
3. While no grant is active, open settings. Verify both app-list edits and waiting-time edits are blocked. Let a wait finish but cancel without selecting/granting access; settings must stay locked.
4. Request Temporary Unlock. Verify immediate countdown with no extra Start/Wait button. At zero, select apps and a preset duration, grant access, and open the selected app successfully. Unselected restricted apps remain shielded.
5. During this grant, settings become editable. Let it expire while settings/the app picker is still open and verify changes are rejected and the app is shielded again.
6. Set None during an active grant. Lock again; settings must lock again too. A new unlock request skips the countdown but still requires selection and an actual grant before settings become editable.
7. Test every preset with LockIn backgrounded, including 30 seconds, then test early relock, reboot, locked screen, denied/revoked authorization, and missing monitoring. Record the measured relock times; a simulator cannot validate these OS effects.
8. For Flappy Bird, verify portrait nose movement controls the bird responsively at normal lighting, nose loss pauses the game, background/resume works, score increments, and level 50 continues indefinitely without increasing difficulty.

Reference: [ManagedSettingsStore](https://developer.apple.com/documentation/managedsettings/managedsettingsstore), [isActive](https://developer.apple.com/documentation/managedsettings/managedsettingsstore/isactive), [token refresh](https://developer.apple.com/documentation/managedsettings/managedsettingsstore/refresh(_:)-65mti), [DeviceActivityCenter callback timing](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter), and [Vision nose landmarks](https://developer.apple.com/documentation/vision/vnfacelandmarks2d/nose).
