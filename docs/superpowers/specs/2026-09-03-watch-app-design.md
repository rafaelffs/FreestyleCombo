# FreestyleCombo for Apple Watch

## Problem

The user wants to browse their combos from an Apple Watch: list combos
filtered the same way the phone app does (All / Public / Mine / Favourites /
Done), open a combo to see its trick sequence, and toggle favourite/done
without pulling out the phone.

Flutter has no watchOS target, so this can't extend the existing Dart
codebase. It's a new, native SwiftUI **Watch App** target added to the
existing `mobile/ios/Runner.xcodeproj`, talking directly to the existing
REST API.

## Non-goals

- No generating, building, or editing combos from the Watch.
- No rating combos from the Watch.
- No admin features (approvals, user management) from the Watch.
- No standalone login UI on the Watch — auth is inherited from the paired
  iPhone (see below). If the iPhone has never logged in, the Watch app has
  nothing to show but a "log in on your iPhone" empty state.
- No refresh-token handling beyond what the API already has (7-day JWTs, no
  refresh token) — an expired token just prompts a reconnect, same as it
  would on the phone.
- No independent watchOS complications or background refresh in v1 — the app
  fetches fresh data each time a screen appears, nothing more.

## Architecture

- New target: **FreestyleCombo Watch App** (SwiftUI, watchOS 10+), added via
  Xcode's File → New → Target → Watch App flow, embedded in the existing
  `Runner` target (the standard "Watch App bundled in an iOS app" structure
  Xcode scaffolds — WatchKit Extension + Watch App as dependents of Runner).
- No Flutter code, no Dart, no shared code with `mobile/lib/` — a fresh
  Swift package alongside it. Talks to the same production API
  (`https://www.fscombo.com/api` in release, same `kBaseUrl`-style
  release/debug split as the iOS app) directly over the Watch's own network
  connection (WiFi or cellular on cellular-capable models) — not relayed
  through the phone for data, only for the initial auth handoff (see below).
  This means the Watch works even when out of Bluetooth range of the phone,
  as long as it has its own network access.
- No backend changes. Every endpoint the Watch needs already exists:
  `GET /api/combos/public`, `GET /api/combos/mine`,
  `GET /api/combos/favourites`, `GET /api/combos/{id}`,
  `POST`/`DELETE /api/combos/{id}/favourite`,
  `POST`/`DELETE /api/combos/{id}/complete`. "All" is the same client-side
  merge-and-dedupe the phone's `_fetchAllCombined()` does
  (`combos_screen.dart`), reimplemented in Swift. "Done" is a client-side
  filter on `isCompleted`, matching the phone's `_matchesDoneFilter`.

## Auth handoff

- iPhone side: `AuthService` (`mobile/lib/core/auth/auth_service.dart`)
  gains one addition — whenever it sets a JWT (login, register-then-login,
  or app launch with an existing valid token), it also calls into a small
  native bridge (a Flutter platform channel, since `WatchConnectivity` has
  no Dart binding) that does
  `WCSession.default.updateApplicationContext(["jwt": token, "userName":
  name, "expiresAt": expiry])`. `updateApplicationContext` (not
  `sendMessage`) because it persists the *latest* value and delivers it
  whenever the Watch is reachable, rather than requiring both devices to be
  awake and in range at the same instant.
- Watch side: implements `WCSessionDelegate.session(_:didReceiveApplicationContext:)`,
  stores the JWT in the Watch's own Keychain (not synced/shared Keychain —
  each device keeps its own copy, refreshed by the context push).
- On a `401` from any API call, the Watch shows a lightweight "Open
  FreestyleCombo on your iPhone to reconnect" empty state instead of
  retrying — logging in again on the phone re-triggers the context push
  automatically, no explicit "resync" action needed on the Watch.
- First-run state (Watch installed but no context ever received): same
  empty state, worded as "Log in on your iPhone first."

## Screens & navigation

Three screens, `NavigationStack`-based push navigation (approach "menu →
list", matching watchOS's own Mail/Messages/Alarms pattern):

1. **Filter menu** (root) — five rows: All, Public, Mine, Favourites, Done.
   Each row shows a count, fetched lazily (not blocking the menu's initial
   render — rows show a placeholder until their count resolves).
2. **Combo list** (pushed from a menu row) — compact `List` of cards: combo
   name-or-abbreviation-sequence, difficulty badge, "by owner". Swipe left
   on a row for Favourite, swipe right for Done (SwiftUI `.swipeActions`) —
   these call the same endpoints the phone uses and just refetch the list
   on success (no per-row local state to keep in sync, sidestepping the
   staleness bug just fixed in `ComboCard`).
3. **Combo detail** (pushed from a list row) — numbered trick sequence in
   abbreviation notation only (no full names — not enough width), no header
   stats, no action buttons. Pure read view.

## Data flow

Every screen fetches on `.task { }` (appear) — no caching layer, no
persistence beyond the Keychain-stored JWT. This matches the phone's
`FutureBuilder`-on-each-visit pattern rather than introducing a new state
model to keep in sync across two platforms.

## Build & distribution

- New bundle ID `com.rafaelffs.freestyleCombo.watchkitapp` (plus the
  standard `.watchkitapp.watchkitextension` id watchOS packaging still
  expects on older toolchains — confirm which is actually required against
  the Xcode version in use when this is built), registered the same way the
  iOS bundle ID was (`create_app`-style addition to
  `mobile/fastlane/Fastfile`).
- Manual signing, same pattern as `Runner` — a new provisioning profile via
  `sigh`, wired into `setup_signing`.
- `fastlane ios build`/`beta` should pick this up automatically once the
  Watch App target is embedded in Runner's "Frameworks, Libraries, and
  Embedded Content" — **not yet verified**; if `flutter build ipa` doesn't
  archive the embedded Watch target correctly, fall back to a raw
  `xcodebuild archive`+`-exportArchive` pair for the whole scheme (the same
  kind of fallback already used for `ExportOptions.plist` per the "release
  build pipeline" lessons in `CLAUDE.md`).
- Purely additive to the current release train — does not touch or
  invalidate iOS build 9, currently `WAITING_FOR_REVIEW`. Ships as build 10+
  whenever this work is ready.

## Error handling

- Network failure (no connectivity at all): a retry-able error state per
  screen, matching the phone's `_errorView` pattern.
- `401`: the "open your iPhone" reconnect state described above.
- Empty list (e.g., no favourites yet): a short empty-state message per
  filter, mirroring the phone's per-tab empty states.

## Testing

- No unit test suite exists for the iOS app today (`mobile/` has no test
  target beyond `RunnerTests`, which is Flutter's default smoke test) — this
  spec doesn't introduce one. Verification is manual: run on a paired
  Simulator (Watch Simulator paired to an iOS Simulator) or a physical
  Watch, confirm each filter's list matches what the phone shows for the
  same account, confirm swipe actions reflect on the phone after refresh,
  confirm the reconnect flow after logging out on the phone.
