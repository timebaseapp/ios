# Timebase iOS

Native iOS app — a world clock you actually want to open, with calendar-aware event countdowns.

Spiritual successor to **Globo**.

## Build

Requires Xcode 16+, iOS 17+ simulator, [xcodegen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project Timebase.xcodeproj -scheme Timebase \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO
```

Then open `Timebase.xcodeproj` in Xcode and run.

## Architecture

- SwiftUI, iOS 17+, single app target
- `@Observable` `TimebaseStore` — cities, scrub state, events
- `EventKit` for calendar (covers Apple/Google/Exchange/iCloud)
- `NSUbiquitousKeyValueStore` for iCloud sync
- OKLCH color interpolation per row (`Color/TimeColor.swift`)
- Universal scrub gesture (`Gesture/UniversalScrub.swift`) — `dx + (-dy)`
- Zero third-party dependencies

## Cities dataset

`Sources/Timebase/Resources/cities.json` is a curated subset (~150 major cities). The canonical version lives in [`timebaseapp/web`](https://github.com/timebaseapp/web/blob/main/cities.json) — copy from there when adding cities.

## Design

See the project plan in the workspace; this repo follows the same color palette, type system (SF Pro, 13/17/22/28/48), and motion specs as the web counterpart.
