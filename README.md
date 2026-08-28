# LockIn 🔒

An iPhone app for discipline, focused work, and intentional screen-time control.

> Control your phone instead of letting your phone control you.

## MVP

The current build includes:

- Screen Time authorization and Apple's privacy-preserving app/category picker
- Timed and end-time focus sessions with their own app selections
- Recurring blocking schedules, including overnight schedules and weekday selection
- Custom shield copy with the block's end time
- Optional verified math challenges
- Optional honor-based exercise, weighted exercise, reading, cleaning, and custom challenges
- Verified math, question, and small-puzzle challenges
- Confirmed emergency unlocks
- Countdown timer with selectable completion sounds
- Work/rest interval timer with rounds and automatic advancement
- Daily and weekly focus time, completed sessions, challenges, selected distractions, and emergency-unlock history
- Home Screen and Lock Screen widgets with focus status, progress, and Focus/Timer quick actions
- Shared state across the app and its Screen Time extensions

## Project structure

- `FocusApp/` — SwiftUI application, shared models, persistence, and blocking engine
- `Extensions/LockInWidgets/` — Home Screen and Lock Screen widgets
- `Extensions/DeviceActivityMonitor/` — activates and clears scheduled shields
- `Extensions/ShieldConfiguration/` — customizes the system blocking screen
- `Extensions/ShieldAction/` — routes unlock requests back to LockIn
- `scripts/generate_xcodeproj.rb` — reproducibly generates the Xcode project

## Requirements

- A Mac with full Xcode 26 or later and a current iOS SDK
- An Apple Developer Program membership
- A physical iPhone running iOS 18 or later
- Family Controls development capability for local testing
- Family Controls distribution approval for TestFlight

See [TESTFLIGHT.md](TESTFLIGHT.md) for signing, entitlement, device-test, and upload steps.

## Privacy

LockIn is local-first. The MVP has no account, analytics, advertising, or server. App selections are represented by Apple's opaque Screen Time tokens, and app state is stored in the app's private shared container.

## Status

MVP source is implemented. Debug and Release physical-iPhone builds succeed with Xcode 26.5 and the iOS 26.5 SDK, and the unsigned archive contains the app plus all three embedded Screen Time extensions. Property-list, privacy-manifest, bundle-validation, archive-structure, and repository checks pass.

Signing, Family Controls distribution approval, and testing on a physical iPhone remain necessary before TestFlight distribution. Apple's Screen Time behavior cannot be meaningfully validated solely in the simulator.

## License

MIT License. See [LICENSE](LICENSE).
