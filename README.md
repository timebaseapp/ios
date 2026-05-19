<div align="center">

# Timebase

#### *A quieter way to think across timezones.*

[**timebase.cc**](https://timebase.cc) &nbsp;·&nbsp; [App Store](https://apps.apple.com/app/id6770247920) &nbsp;·&nbsp; [@amrith](https://x.com/amrith)

</div>

---

Timebase is a world clock and meeting planner for people who live across time zones. It runs offline, syncs only via your own iCloud, and asks for nothing.

There's no signup. No analytics. No servers we control. The app does its thinking on your device and keeps it there.

## In v1

| | |
|---|---|
| 🌐 &nbsp; **World Clock** | Up to 8 cities, ordered by offset. Time-of-day gradients flow with the hour, anywhere on Earth. Scrub vertically to see how the day looks somewhere else. |
| 📅 &nbsp; **Meeting Planner** | Pick participants by city. Anchor the meeting to anyone's timezone — your home or theirs. Save straight to Calendar. |
| ⏳ &nbsp; **Up Next** | Native Calendar integration. Real countdowns to your real events. |
| 📱 &nbsp; **Widgets** | Home + lock screen, every size. World Clock and Up Next, side by side. |
| ⚡ &nbsp; **Live Activities** | A ticking countdown card on the lock screen. The Dynamic Island gets a small gradient dot + timer for the next 60 minutes before any event. |
| 🎙️ &nbsp; **Siri & Shortcuts** | *"Hey Siri, what time is it in Tokyo?"* Indexed by Spotlight. App-icon long-press for the rest. |
| 🎛️ &nbsp; **Control Center** | One-tap Timebase tile on iOS 18+. |

## How it's built

SwiftUI, iOS 17+, Swift 6 strict concurrency. One main target plus a widget extension. No third-party dependencies.

- `TimebaseStore` — `@Observable`, `@MainActor`, the single source of truth
- `EventKit` for Calendar across Apple / Google / Exchange / iCloud
- `WeatherKit` for per-city weather in the detail sheet
- `NSUbiquitousKeyValueStore` for cross-device sync via the user's iCloud
- `ActivityKit` for the Dynamic Island + lock-screen Live Activity
- `App Intents` for Siri / Shortcuts / Spotlight
- An OKLCH palette per fractional hour, with a paper-grain texture overlay

## Build it

Requires Xcode 16+ and [xcodegen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
open Timebase.xcodeproj
```

Or, headlessly:

```sh
xcodebuild -project Timebase.xcodeproj -scheme Timebase \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build CODE_SIGNING_ALLOWED=NO
```

## Ship it

```sh
bundle exec fastlane beta      # → TestFlight
bundle exec fastlane release   # → App Store Connect (binary, no auto-submit)
```

Fastlane handles provisioning, signing, build-number bumping, and the upload. App Store metadata for all 10 US-indexed locales lives under `fastlane/metadata/` and pushes via `bundle exec fastlane push_metadata`.

## Cities

`Sources/Timebase/Resources/cities.json` is a curated set of ~150 cities. The canonical copy lives in [`timebaseapp/web`](https://github.com/timebaseapp/web/blob/main/cities.json) — sync from there when adding new ones.

---

<div align="center">

*Crafted by [@amrith](https://x.com/amrith) in Amsterdam.*

</div>
