# LockIn final adjustments — 22 November 2026

## Scope and distribution state

Four focused follow-ups on merged source `8ca4ea4fd36ea591d13c32df583b3911033d9cd6`.
This local development change does not authorize publication, signing or an Apple
upload. Version/build remain unchanged; the existing TestFlight artifact does not
contain these follow-ups. No minigames, navigation destinations, calendar rules,
game-round/summary features, timers or alarms are added or removed.

## Implementation

1. **Pushup icon:** retain the exact supplied 1280×853 JPEG; display it at 64-point
   width rather than 58 inside the same 58×58 icon. The figures are centered and
   proportional; the overflow consists only of unused black margins. Source SHA-256:
   `2107f3bc2dc1dc4b49aed80e841bf6fe73ccbe087cc1c629effa42f75338980b`.
2. **Flappy:** detect eye outlines, use the midpoint of each eye's horizontal
   endpoints, and take the screen-left eye as the visual reference. No pupils,
   iris motion, gaze or nose position supplies the control signal. Project the
   measured eye-line height into the same aspect-fill camera viewport. Place the
   bird beside the eye before play, fixing its X for that round. A small reference
   ring marks the eye-line. Existing time-based smoothing, jitter suppression and
   movement-rate cap remain. Camera pose is a veto, never a movement input: changes
   over 0.07 radians pitch or 0.10 radians roll from calibration hold the last
   control height. Start/restart calibrates the natural push-up posture. This is
   conservative pose rejection, not a claim of perfect 3D compensation. Physical
   acceptance must check natural movement, responsiveness and rejected nods.
3. **Unlock:** the dedicated camera mode uses only face rectangles, with no
   landmarks, expression, mouth/chin test, gaze, identity or capture-quality
   threshold. A brief missed detection pauses earned time; it does not reset it or
   earn missing time. Continuous absent detections for 0.75 seconds reset progress.
   A capture/delivery gap over 0.5 seconds still invalidates progress. Background,
   inactive state and dismissal still cancel the wait. Existing wait choices,
   immediate None, selection/grant/relock paths remain unchanged. Detection
   uncertainty cannot prove a face is still present; sustained detector loss must
   fail closed, even when caused by occlusion.
4. **Restrictions:** remove the redundant Temporary Unlock heading/description.
   Pin the existing action states at the bottom of the content safe area with
   24-point lower spacing and the unchanged navigation-height clearance. Activity
   remains scrollable. Keep authorization, settings, retry, active-grant and relock
   actions as well as the original bottom navigation implementation.
   The white button retains its normal 58-point minimum height and can grow to
   accommodate wrapped accessibility text instead of clipping it.

## Verification plan

- Pure policies: positive eye-line motion, nod/roll veto, eye-outline changes,
  smoothing/rate cap, aspect-fill projection; brief detection loss earns nothing,
  confirmed absence/stalls reset, lifecycle and grant regressions.
- Full simulator suite including existing calendar, game, timer and storage tests.
- Active-scene render captures at 320×568 and 440×956 for Restrictions and the
  minigame grid; additional compact accessibility text and native icon captures.
  Inspect PNGs, not just successful image encoding. Unsigned root captures use the
  real Retry fallback action, not manufactured Screen Time tokens.
- Unsigned iPhone Release build and six-bundle audit; retain existing alert sound.
- Diff, whitespace and private-path/secret checks; verify supplied asset unchanged.

Reproducible local commands (select an installed iPhone simulator if its name differs):

```sh
swift test
xcodebuild -project FocusApp.xcodeproj -scheme FocusAppTests -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/simulator CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO test
xcodebuild -project FocusApp.xcodeproj -scheme FocusApp -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build/device CODE_SIGNING_ALLOWED=NO build
python3 scripts/release.py audit-app --app build/device/Build/Products/Release-iphoneos/LockIn.app
```

## Physical acceptance — outstanding

- With a face otherwise in frame, open/close mouth, change expressions and touch
  chin repeatedly. Earned time should survive brief uncertain samples; missing
  intervals must not count. Leave frame long enough to confirm loss: full reset.
- Cover/uncover camera, stall capture, background/dismiss/reenter, and finish a
  wait/select apps/grant/relock on a signed iPhone. No lifecycle bypass.
- In natural push-up posture, move the eye-line vertically without nodding; bird
  follows beside the reference. Nod/roll in place: no steering. Move only pupils
  or gaze: no steering. Check blinking, face loss, resume and restart calibration.
- On small/large iPhones check the actual Temporary unlock action's position,
  Settings, navigation, VoiceOver and large text. Simulator rendering is not
  physical Screen Time acceptance.

## Results

- Core: **48/48 passed**, including eye-line movement and calibration after
  detection loss, nod/roll veto and unlock dropout/stall policies.
- Full iPhone simulator suite: **61/61 passed**, no failed tests. This includes
  all existing functional regressions and four UI-render cases. The first test
  build used an outdated visibility boundary for the button style; rebuilding
  against the corrected final app source resolved it.
- Inspected 320×568 and 440×956 Restrictions/grid captures: no redundant heading
  or description; lower white action remains fully above unchanged navigation;
  both complete pushup figures are centered, proportional and uncropped.
- Compact accessibility capture: the lower action remains accessible while the
  activity area can scroll. The real Temporary unlock label/style is also
  rendered separately at accessibility3 and wraps fully inside its white button.
  Root captures use the unsigned Retry fallback; they do not claim signed-device
  authorization or enforcement.
- Render-only final rerun: **4/4 passed**. The standalone icon capture ignores
  the host scene safe area; all six full-screen/button captures match the already
  inspected full-suite PNGs byte-for-byte. The final icon capture was inspected
  separately; complete figures remain within the icon bounds.
- Source image byte hash matches the supplied image; no EXIF, XMP or comment
  metadata. Changed-file secret, email, absolute-private-path and whitespace
  checks clean. Existing public application identifiers are intentional.
- Local logs, result bundle and inspected captures are retained in ignored build
  outputs. Free space before checks: 20 GiB; latest measurement: 19 GiB. No build
  outputs or older release artifacts were deleted.
- Unsigned iPhone Release build: **passed**. Bundle audit: **six expected bundles
  passed**. Existing alert sound is retained unchanged. No signing performed.
- Physical-camera and signed-device acceptance above remains **not executed**.
- No new push, merge, archive, IPA, Apple validation or TestFlight upload.
