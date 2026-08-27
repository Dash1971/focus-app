# Focus App

An iPhone app for discipline, focused work, and intentional screen-time control.

> Control your phone instead of letting your phone control you.

## MVP

The current build includes:

- Screen Time authorization and Apple's privacy-preserving app/category picker
- Immediate focus sessions that shield selected apps and websites
- Recurring blocking schedules, including overnight schedules and weekday selection
- Custom shield copy with the block's end time
- Optional verified math challenges
- Optional honor-based exercise, reading, cleaning, and custom challenges
- Confirmed emergency unlocks
- Countdown timer with completion notification
- Work/rest interval timer with rounds and automatic advancement
- Daily focus time, completed sessions, challenges, and emergency-unlock history
- Shared state across the app and its Screen Time extensions

## Project structure

- `FocusApp/` — SwiftUI application, shared models, persistence, and blocking engine
- `Extensions/DeviceActivityMonitor/` — activates and clears scheduled shields
- `Extensions/ShieldConfiguration/` — customizes the system blocking screen
- `Extensions/ShieldAction/` — routes unlock requests back to Focus
- `scripts/generate_xcodeproj.rb` — reproducibly generates the Xcode project

## Requirements

- A Mac with full Xcode and an iOS 18 SDK
- An Apple Developer Program membership
- A physical iPhone running iOS 18 or later
- Family Controls development capability for local testing
- Family Controls distribution approval for TestFlight

See [TESTFLIGHT.md](TESTFLIGHT.md) for signing, entitlement, device-test, and upload steps.

## Privacy

Focus is local-first. The MVP has no account, analytics, advertising, or server. App selections are represented by Apple's opaque Screen Time tokens, and app state is stored in the app's private shared container.

## Status

MVP source is implemented. Static Swift syntax, property-list, privacy-manifest, project-structure, and repository checks pass. A signed device build remains necessary because Apple's Screen Time frameworks cannot be meaningfully tested in a command-line-only environment or solely in the simulator.

## License

MIT License. See [LICENSE](LICENSE).
