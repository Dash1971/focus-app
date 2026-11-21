# LockIn update acceptance — 22 November 2026

## Scope

Seven requested follow-ups, preserving the current design and unrelated features.
Source base: `c3dfbe4c37ed7c9fa0873139d5673d17098795f3`.
No repository publication, release activation, signing or Apple upload is included.

1. **Unlock camera:** full-screen front-camera preview and countdown. Bounding-box
   face presence only: no pupils, gaze direction or identity matching. The entire
   configured wait must be earned from consecutive fresh frames. Face loss resets
   it; capture/delivery gaps over 0.5 seconds cannot earn time. Inactive/background
   and dismissal cancel the wait, including completed-but-ungranted access. Existing
   None/10/20/30/45/60 settings and unlock-duration choices remain unchanged.
2. **Flappy vertical input:** upper nose-crest/bridge position in camera coordinates,
   with time-based smoothing, jitter deadband and a movement-rate cap. No pupil
   measurements. Existing bird X position (72 points), scoring, pipes and difficulty
   are untouched. Sustained landmark loss still pauses gameplay.
3. **Pushup icon:** exact supplied JPEG copied unchanged into the existing
   `PushupFriends` asset. Aspect-fit inside the existing 58-point icon area, black
   background, white figures; no recreation or distortion.
4. **Rounds:** 5, 10 or Endless before choosing 2, 3 or 4 players. Endless has a
   confirmed Finish game action and no automatic ten-round stop.
5. **Summary:** confirmed cards populate round/player records. SKIP is 0; unplayed
   turns are distinct from 0. Drawn but unconfirmed cards do not count, including
   when finishing Endless mid-round. Per-player rows, totals, group total and bar
   chart all use those same records. Done is self-reported exercise completion,
   not camera verification. Replay clears the previous game's data.
6. **Calendar:** immutable built-in overlay, separate from local editable events.
   Japanese official data includes substitute/citizen holidays and historical
   exceptions. Future current-rule dates are projected and marked. Gregorian Easter,
   Easter-adjacent dates, Lunar New Year, regional Mother’s/Father’s Day, US
   Thanksgiving and selected annual worldwide/Japanese observances recalculate per
   year. Civil-date lookup works with non-Gregorian display calendars and time zones.
7. **Restrictions:** normal-flow scrollable content rather than a viewport-height spacer,
   with a fixed 28-point gap after activity and 36 points of bottom content clearance. Temporary Unlock title, description
   and current action stay together. On constrained screens, an explicit 48-point safe-area
   allowance for the unchanged main bar plus initial scroll anchoring reveal the
   bottom action; shorter content remains top-aligned. The bottom
   navigation implementation is unchanged.

## Holiday provenance and limits

- [Japan Cabinet Office](https://www8.cao.go.jp/chosei/shukujitsu/gaiyou.html): official
  [civil-date CSV](https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv), retrieved
  22 November 2026; 1,067 dates covering 1955–2027. All names/dates are public data.
- [NAOJ equinox guidance](https://www.nao.ac.jp/faq/a0301.html): future equinoxes are
  predictions until officially announced. The 2028–2099 rule calculations are not
  represented as official declarations. One-off future legal changes need updates.
- [US Naval Observatory Easter guidance](https://aa.usno.navy.mil/faq/easter):
  Gregorian computus; other Christian traditions may use different dates.
- [United Nations observances](https://www.un.org/en/observances/list-days-weeks):
  selected annual international days. This is a curated set, not worldwide exhaustive
  public-holiday coverage. Lunar New Year uses Foundation's Chinese calendar.
- No calendar account, permission, remote feed or runtime network request is added.

## Automated and local verification

Final results are recorded in the closeout below. Regression coverage includes
fresh-frame wait completion, resets/cancellation/stalls, all finite game modes and
player counts, stale taps, Endless after twelve rounds, partial summaries, SKIP,
Codable round trips, nose-control direction/rate limiting, moving holiday dates,
official 2026/2027 holiday sets, future labels and time-zone/calendar lookup.

## Physical-device acceptance — not executed by simulator tests

- Test every nonzero wait with a visible face throughout. Confirm the countdown does
  not move without a face, resets when covered/out of frame, and cannot finish from
  a frozen/interrupted camera. Turn eyes away without hiding the face: it must still
  count. Cover pupils but leave the face detectable: no gaze check is intended.
- Test first permission grant, denial, Settings return, incoming interruption,
  Home/app switch, screen lock, force quit and reentry. No completed wait/grant
  survives cancellation. None remains immediate by explicit compatibility choice.
- Finish a wait, select blocked items, grant access; verify only those items unlock
  and existing relock behavior works on the physical device.
- Test nose-bridge vertical movement, head tilt, looking around with stationary
  head, face loss and background/resume. Judge stability and responsiveness on a
  real front camera; verify X behavior is unchanged.
- On small/large iPhones and large Dynamic Type, check Temporary Unlock's title,
  explanation and action above the navigation bar. On constrained screens, scroll
  to the whole section; navigation must not move or cover it.
- Verify the exact icon, all player/mode choices, finish confirmation, summaries,
  all-SKIP games, partial last rounds and replay on one shared phone. VoiceOver must
  announce chart totals; no actual rep sensor is claimed.
- Browse holidays across December/January and leap years. Create/edit/delete a user
  event on a built-in holiday; the holiday remains and the saved event works normally.

## Closeout

**Done locally.** No GitHub publication, signing, Apple validation or TestFlight
upload was performed. Existing release version/build metadata is unchanged; this
is a development branch, not an approved distribution artifact.

- Core policies: **43/43 passed** (`swift test`).
- iPhone simulator: **52 functional regressions passed**, plus the compact/large
  layout capture test (**53 checks total**). After correcting the capture method,
  the render-only rerun also passed. Captures use an active UIWindowScene and
  `drawHierarchy(afterScreenUpdates: true)`, not incomplete layer snapshots.
- Unsigned Release iPhone build: **passed** on final app source.
- Release controller bundle audit: **passed, six bundles**. Existing alert sound retained.
- Visual review at **320×568** and **440×956**: Temporary Unlock title, description
  and action fully visible and clear of the unchanged navigation bar. The compact
  view initially scrolls to keep the action visible; the upper activity content can
  be scrolled back into view. These are render checks, not physical-device acceptance.
- Supplied JPEG copied unchanged; source SHA-256:
  `2107f3bc2dc1dc4b49aed80e841bf6fe73ccbe087cc1c629effa42f75338980b`.
  No EXIF, XMP or comment metadata found. Source path/secret scan and whitespace check clean.
- Local logs, bundle audit and reviewed renders are preserved under ignored
  `build/verification/`; no machine-local log paths or credentials are published.
- Build/test outputs were retained (not deleted). Free space: 27 GiB before the
  checks, 21 GiB at closeout. No archive, IPA or immutable release run was created.
- Physical-camera behavior and signed-device Screen Time enforcement remain the
  explicit unexecuted acceptance items above.
