<div align="center">

# 🏠 HomeBar

**Your Home Assistant, one click from the menu bar.**

Glance at your sensors and flip your lights, A/C, switches, and automations —
without opening a browser or reaching for your phone.

[![CI](https://github.com/NorbertRop/homebar/actions/workflows/ci.yml/badge.svg)](https://github.com/NorbertRop/homebar/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![Status](https://img.shields.io/badge/status-private%20beta-lightgrey)

</div>

## Screenshots

<!-- Drop a capture at docs/screenshot.png and uncomment:
<p align="center"><img src="docs/screenshot.png" width="360" alt="HomeBar menu"></p>
-->

> 📸 _Coming soon._

## What It Shows

HomeBar lives in your menu bar and answers, at a glance:

- **Is everything OK?** — a connection dot and an offline/stale counter for the things you care about.
- **What are my rooms doing?** — entities grouped by area, with sensor devices kept together on their own cards.
- **Quick controls first** — lights, climate, switches, and automations float to the top of each room; readings sit below.

## Features

- 🔴 **Live** — a persistent WebSocket keeps state current; sliders push changes to Home Assistant as you drag (throttled, no flooding).
- 💡 **Lights** — toggle, brightness, color temperature, plus an in-menu hue scrubber and one-tap color/white swatches.
- ❄️ **Climate / A/C** — a compact thermostat tile: target temp between `−`/`+`, current temp, mode and fan. Controls hide when the unit is off.
- 🔌 **Switches & automations** — toggle switches, run or arm/disarm automations.
- 🧹 **Vacuum** — start (vacuum / vacuum + mop / mop), pause, and dock.
- 🔔 **Alerts** — get notified when the devices you've pinned go offline or stale.
- 🗂️ **Make it yours** — pin favorites, reorder anything (right-click → Move, or drag in Settings), hide noise, and optionally show diagnostic entities. Offline and disconnected devices are hidden by default.
- 🍎 **Native** — SwiftUI menu-bar-only app, launch-at-login, no Dock icon. Your token is stored in a `0600` file, never in plist or source.

## Install

### Download

> ⏳ Notarized downloads aren't published yet. For now, **build from source** (below).
> Once a release is cut, grab `HomeBar.zip` from [Releases](https://github.com/NorbertRop/homebar/releases),
> unzip it to `/Applications`, and — because builds are currently ad-hoc signed —
> right-click the app → **Open** the first time (or run `xattr -dr com.apple.quarantine /Applications/HomeBar.app`).

### Build from source

Requires macOS 14+ and a Swift 6 toolchain (Xcode 16 or newer).

```bash
git clone git@github.com:NorbertRop/homebar.git
cd homebar
./Scripts/package-app.sh release          # builds + bundles build/HomeBar.app
cp -R build/HomeBar.app /Applications/     # install
open /Applications/HomeBar.app
```

## Configuration

On first launch, open **Settings** (gear icon) and add:

1. **Server URL** — e.g. `http://homeassistant.local:8123` or `http://<ip>:8123`.
2. **Long-lived access token** — Home Assistant → your profile → *Long-Lived Access Tokens* → *Create Token*.

The token is saved to `~/Library/Application Support/HomeBar/token` with `0600` permissions.
For headless/dev use you can instead set `HOMEBAR_URL` and `HOMEBAR_TOKEN` in the environment.

## CLI

`homebarcli` is a small companion for debugging the Home Assistant connection:

```bash
swift run homebarcli states           # dump current entity states
swift run homebarcli watch            # stream state_changed events live
swift run homebarcli toggle light.desk_lamp
swift run homebarcli call light turn_on light.desk_lamp brightness_pct:40
```

It reads the same `HOMEBAR_URL` / `HOMEBAR_TOKEN` environment variables.

## Development

```bash
swift build           # debug build of all products
swift test            # run the test suite (40 tests)
swift run homebar     # run the app straight from SwiftPM
```

### Project layout

| Path | What |
| --- | --- |
| `Sources/HomeBarCore` | Pure, testable core — HA WebSocket client, domain models, grouping, settings, token storage. No UI. |
| `Sources/HomeBar` | The SwiftUI menu-bar app (`MenuBarExtra`, rows, settings). |
| `Sources/homebarcli` | Command-line companion for poking the connection. |
| `Tests/HomeBarCoreTests` | Swift Testing suite over the core. |
| `Scripts/package-app.sh` | Bundles the `homebar` binary into `HomeBar.app` and ad-hoc signs it. |

The app keeps all Home Assistant logic in `HomeBarCore` so it can be unit-tested without a UI; the SwiftUI layer is a thin, observable view on top.

## Roadmap

- [ ] Notarized, Developer ID–signed release builds (no Gatekeeper prompt)
- [ ] Homebrew cask for one-line install
- [ ] Screenshots & a short demo clip
- [ ] Scenes & cover/blind controls

## License

Private — all rights reserved, for now. A license will be chosen before any public release.
