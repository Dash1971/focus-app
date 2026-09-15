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
