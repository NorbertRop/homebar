# HomeBar — Design Spec

- **Date:** 2026-06-02
- **Status:** Approved (v1 scope)
- **Working name:** HomeBar (rename later)

## 1. Summary

HomeBar is a native macOS **menu-bar app** that surfaces live **Home Assistant**
state and lets you control devices without opening the HA web UI. It is modeled on
[RepoBar](https://github.com/steipete/RepoBar) (steipete) — the same *shape* of app
(glanceable status cards + click-through actions in a `MenuBarExtra`, cache-first,
background-refreshed), but "repos with CI status" become "sensors with readings" and
"click-through actions" become "switches / lights / climate / automations".

## 2. Goals

- Glance at sensor readings from the menu bar; act on devices in one or two clicks.
- Real-time updates via Home Assistant's WebSocket API.
- Native macOS feel (SwiftUI `MenuBarExtra`), faithful to RepoBar.
- One alert in v1: **device offline / stale** native notification.
- A testable core library + a debug CLI, mirroring RepoBar's structure.

### Primary devices (the user's current real setup — must work well in v1)

- A **color light** (`light` domain, RGB + brightness, possibly color-temp).
- An **A/C unit** (`climate` domain — target temp + HVAC mode, *not* a plain switch).
- An **environment sensor** reporting **temperature, CO₂, pressure, humidity** — in HA this
  is one physical *device* exposing several `sensor.*` entities (`device_class`
  temperature / carbon_dioxide / atmospheric_pressure / humidity, each with its own unit),
  which should render **grouped as one device card**, not scattered.

These drive the v1 control surface. Other entity types are supported generically and
the exact entity list is tuned against the user's HA later.

## 3. Scope

### In scope (v1)

- **Monitor:** `sensor.*` and `binary_sensor.*` — show live readings with units and a
  freshness indicator.
- **Control:**
  - `switch.*` — on/off toggle.
  - `light.*` — toggle, brightness, **color** (RGB and/or color-temp).
  - `climate.*` — power, target-temp stepper, HVAC-mode picker, fan mode (if available).
  - `automation.*` — run on demand (`trigger`) and arm/disarm (`turn_on`/`turn_off`).
- **Organization:** discover all entities, group by HA **Area** (room) with a **Pinned**
  section on top; within an area, entities belonging to the same physical **device** render
  together as a labeled **device card** (e.g. a temp/CO₂/pressure/humidity sensor shows as
  one block); entities with no assigned area fall under an **Unassigned** group at the
  bottom; RepoBar-style **Pinned / Visible / Hidden** per entity.
- **Alert:** native notification when an entity goes **offline / stale** (and a recovery
  notice when it returns).
- **CLI:** `homebarcli` for headless debugging.

### Out of scope (v1 — explicitly deferred)

- Scenes & scripts (trivial to add later — same `call_service` mechanism).
- App-side rule engine ("if temp > X then …") — HA already does this server-side.
- Threshold alerts and critical-state-trip alerts (only offline/stale in v1).
- Backends other than Home Assistant (a `Backend` protocol seam can be added later if a
  second backend ever appears — YAGNI now).
- Auto-discovery of HA host (user enters the URL).

## 4. Platform & toolchain

- macOS **14+** (Sonoma) — needed for `MenuBarExtra` `.window` style + Observation.
- **Swift 6**, strict concurrency. SwiftUI + AppKit interop where needed.
- **SwiftPM** build (like RepoBar); packaged into a `.app` with `LSUIElement = true`
  (menu-bar-only, no Dock icon). Code-sign for Gatekeeper.

## 5. Architecture — three modules

### `HomeBarCore` (SwiftPM library — no UI, fully unit-testable)

- **`HAClient`** — `actor` owning the WebSocket connection.
  - Auth handshake, request/response matching by message `id`, event subscription.
  - Reconnect with exponential backoff + jitter.
  - Exposes an `AsyncStream<StateEvent>` of deltas and `async callService(...) throws`.
  - WebSocket hidden behind a **`WebSocketTransport`** protocol so the client is testable
    with a scripted fake (no live HA needed).
- **`StateStore`** — `@MainActor @Observable` class the UI binds to.
  - Holds current entity states + area grouping; applies snapshot + deltas.
  - Persists a JSON **state cache** to Application Support for **instant launch**
    (cache-first, like RepoBar): render last-known state immediately, then reconcile once
    the socket connects.
- **`StalenessMonitor`** — periodic check (~30s) using an **injectable clock**; flags
  entities offline/stale and emits *transitions* (de-duped). Notifies via an injected
  `Notifier` protocol (real impl = `UNUserNotificationCenter`).
- **Models** — `HAEntity`, `EntityState`, `HAArea`, `HADevice`, `Domain` (enum),
  `DeviceClass`, plus per-domain view models (`ClimateState`, `LightState`, …).
- **`Settings`** — server URL, staleness thresholds (global + per-entity), pin/hide sets,
  refresh cadence. Codable → Application Support. Token lives in **Keychain**
  (`KeychainStore`), never in the settings file.

### `HomeBar` (the app)

- `@main` SwiftUI `App` with a single `MenuBarExtra` scene using
  **`.menuBarExtraStyle(.window)`** — a SwiftUI panel (not a plain `NSMenu`), which is what
  enables toggles, sliders, color pickers, freshness dots, and grouped sections.
- **`MenuBarLabel`** — always-visible bar content: a house SF Symbol + a small **red dot
  when any device is offline** (the single v1 glance signal).
- **`MenuContentView`** — the panel: connection header, Pinned section, per-Area sections,
  Automations section, footer (offline count · Settings… · Quit).
- **Row views** per domain (see §7).
- **`SettingsView`** — connection setup, entity management, staleness config, launch-at-login.

### `homebarcli` (executable, shares `HomeBarCore`)

- `states [--domain d] [--area a]` — dump current state.
- `toggle <entity_id>` — toggle a switch/light/automation.
- `call <domain> <service> <entity_id> [--data k=v]` — arbitrary service call.
- `watch` — stream `state_changed` events live.
- Reads URL/token from the same Keychain/Settings, or `--url` / `HOMEBAR_TOKEN` env.

## 6. Home Assistant integration

### Auth & connection

- **Long-lived access token** (created in HA profile) → Keychain. Sent in the WS auth
  frame and as `Authorization: Bearer` for any REST fallback.
- Server URL configurable, e.g. `http://homeassistant.local:8123`
  (WS endpoint `ws(s)://<host>/api/websocket`).

### WebSocket handshake & subscriptions

1. Connect → server sends `auth_required`.
2. Client → `{"type":"auth","access_token":"<LLAT>"}` → server `auth_ok` (or `auth_invalid`).
3. `{"id":1,"type":"get_states"}` → full snapshot.
4. Registries for room/device grouping (one-time per connect):
   `config/area_registry/list`, `config/device_registry/list`, `config/entity_registry/list`
   → build `entity → device → area` (with entity-level area override). The `entity → device`
   map also drives **device-card grouping** within an area.
5. `{"id":N,"type":"subscribe_events","event_type":"state_changed"}` → live deltas as
   `event.data.{entity_id, old_state, new_state}`.

Message `id`s are unique and monotonically increasing per connection.

### Actions (`call_service`)

| Device | Service(s) |
|---|---|
| Switch | `switch.turn_on` / `turn_off` / `toggle` |
| Light | `light.turn_on` (`brightness_pct`, `rgb_color:[r,g,b]`, `color_temp_kelvin`), `light.turn_off`, `light.toggle` |
| Climate (A/C) | `climate.set_temperature` (`temperature`), `climate.set_hvac_mode` (`hvac_mode`), `climate.set_fan_mode` (`fan_mode`), `climate.turn_on` / `turn_off` |
| Automation | `automation.trigger` (run now), `automation.turn_on` / `turn_off` (arm/disarm) |

Each call is targeted with `"target":{"entity_id":"…"}` and matched to its `result` by `id`.
REST (`GET /api/states`, `POST /api/services/<domain>/<service>`) is a fallback only.

## 7. UI — menu layout & per-domain rows

```
🏠 HomeBar                          ● Connected
────────────────────────────────────────────
⭐ Pinned
  🌡  Living Room Temp     21.5°C   •
  💡  Desk Lamp                 ◉ on  80% ▦──•  🎨
────────────────────────────────────────────
▾ Living Room
  ❄️  A/C            22°→24° cool ⌄   [− 24° +]  fan: auto ⌄
  ◳ Air Sensor
     🌡  Temperature       21.5°C    •
     🫧  CO₂                640 ppm   •
     💧  Humidity             48%    •
     🧭  Pressure          1013 hPa   •
  🚪  Balcony Door         Closed    •
  💡  Ceiling Light    ◉ on  80% ▦──•  🎨
▾ Bedroom
  🌡  Temperature          19.2°C   ⚠ stale 12m
  🔌  Heater                    ○ off
────────────────────────────────────────────
⚙ Automations
  Morning routine     [▶ Run]   armed  ◉
  Away mode           [▶ Run]   off    ○
────────────────────────────────────────────
⚠ 1 device offline   ·   ⚙ Settings…   ·   Quit
```

Freshness dot `•`: **green** fresh / **amber** stale / **red** offline.

### Row rendering by domain

**Device cards:** when several displayed entities share one physical device (e.g. an air
sensor exposing temperature + CO₂ + pressure + humidity), they render as a labeled group
under the device name rather than scattered rows. Auto-applied when a device has ≥2 visible
entities in an area.

- **Sensor** (`sensor`): name · value + `unit_of_measurement` · freshness dot. Read-only.
  Icon/format keyed off `device_class` — temperature (°C), humidity (%), carbon_dioxide
  (ppm), atmospheric_pressure (hPa), power (W), etc.
- **Binary sensor** (`binary_sensor`): on/off mapped to a human label via `device_class`
  (door open/closed, motion detected/clear, leak/dry, …) · freshness dot. Read-only.
- **Switch** (`switch`): name · toggle.
- **Light** (`light`): toggle · brightness slider · **color control** — SwiftUI
  `ColorPicker` → `rgb_color`, and a warm/cool slider when `supported_color_modes` includes
  `color_temp` (`min/max_color_temp_kelvin`).
- **Climate / A/C** (`climate`): `current_temperature → temperature` · HVAC mode picker from
  `hvac_modes` · target-temp stepper honoring `min_temp` / `max_temp` / `target_temp_step` ·
  fan-mode picker from `fan_modes` (if present) · power (off via mode or `turn_off`).
- **Automation** (`automation`): name · **Run** button (`trigger`) · armed toggle
  (`turn_on`/`turn_off`); `last_triggered` shown on hover.

Optimistic UI: a control reflects the intended state immediately, then confirms against the
service `result` + the echoed `state_changed` (revert if the call fails).

## 8. Data flow

1. **Launch** → load disk cache → render menu instantly.
2. **Connect** → auth → `get_states` + registries → `StateStore` reconciles → UI updates.
3. **Live** → `state_changed` deltas → store → SwiftUI re-renders reactively (Observation).
4. **Act** → `callService` → optimistic update → confirmed by `result` + echoed state.
5. **Watch** → `StalenessMonitor` ticks ~30s → offline/stale transitions → native
   notification + freshness dots + bar badge.
6. **Drop** → exponential-backoff reconnect; entities marked stale past threshold; header
   shows "Reconnecting…".
7. **Persist** → state cache + settings written on change.

## 9. Offline / stale detection

An entity is **offline** when its state is `unavailable` / `unknown`, and **stale** when
`now − last_updated` exceeds its staleness window (global default **15 min**, per-entity
overridable). `StalenessMonitor` tracks prior status per entity and:

- fires a native notification **only on transition** into offline/stale (de-duped),
- fires a **recovery** notification on return to fresh,
- drives the amber/red freshness dots and the menu-bar red offline badge.

## 10. Settings & onboarding

- **First run:** setup window — HA URL + paste long-lived token + **Test connection**
  (runs the auth handshake + `get_states`, shows the entity count). Token → Keychain.
- **Entity management:** searchable list of discovered entities; mark **Pinned / Visible /
  Hidden**. Default heuristic: show `sensor` / `binary_sensor` / `switch` / `light` /
  `climate` / `automation`; hide diagnostic/config entities.
- **Staleness:** global window + per-entity override; toggle offline notifications.
- **Launch at login:** `SMAppService`.

## 11. Persistence & security

- **Token** → Keychain (`Security` framework wrapper). Never written to disk in plaintext.
- **Settings** (URL, thresholds, pin/hide sets, overrides) → Codable JSON in
  `~/Library/Application Support/HomeBar/settings.json`.
- **State cache** → `~/Library/Application Support/HomeBar/state-cache.json`.
- HA timestamps are UTC ISO-8601 — parse with `ISO8601DateFormatter`.

## 12. Testing strategy

`HomeBarCore` with the **Swift Testing** framework:

- **Model decoding** from captured real HA JSON fixtures (`get_states`, `state_changed`,
  registry lists) — including `climate` and color-`light` attribute shapes.
- **`StateStore`** snapshot + delta reconciliation, area grouping, pin/hide filtering.
- **`StalenessMonitor`** transitions with an **injected clock** and a fake `Notifier`
  (assert notify-on-transition, de-dup, recovery).
- **Service payload builders** — light color (`rgb_color` / `color_temp_kelvin`), climate
  (`set_temperature` / `set_hvac_mode`), automation `trigger`.
- **`HAClient`** against a scripted `WebSocketTransport` fake (auth flow, id matching,
  reconnect).

`homebarcli` doubles as a live integration smoke-test against a real HA instance.

## 13. Distribution

- v1: SwiftPM build → bundle `.app` (`LSUIElement = true`) → code-sign → run locally.
- Later: Homebrew cask (`brew install --cask homebar`), like RepoBar.

## 14. Key decisions (and why)

- **Home Assistant backend** — one API unifies every sensor, switch, light, climate, and
  automation; long-lived-token auth; mature WebSocket for real-time.
- **Native Swift / SwiftUI** — user wants the best native macOS feel, not the most
  comfortable language; faithful to RepoBar.
- **Modular (Core + app + CLI)** — testable HA layer, debuggable headless, easy to extend.
- **`.window` MenuBarExtra style** — required for sliders / color pickers / rich rows.
- **Climate promoted to first-class** — the user's A/C is a `climate` entity; on/off alone
  would be a poor experience.
- **Only offline/stale alerts in v1** — high-value, low-complexity; threshold/critical
  alerts deferred.

## 15. Future / later

- Scenes & scripts; threshold + critical-state alerts (e.g. CO₂ > 1000 ppm → ventilate);
  per-area collapse memory; multiple HA instances; `Backend` protocol for non-HA sources;
  Homebrew distribution; optional pinned key-reading text in the menu-bar label.
