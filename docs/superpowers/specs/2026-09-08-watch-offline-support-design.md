# Apple Watch Offline Support — Design Spec

**Status:** Approved. Extends `docs/superpowers/specs/2026-09-03-watch-app-design.md`, which explicitly scoped the original Watch app to "no caching layer, no persistence beyond the Keychain-stored JWT" as a deliberate v1 simplification. This spec reverses that non-goal.

## Problem

The Watch app (`mobile/ios/Watch App Watch App/`) currently has zero local persistence for combo data. Every screen fetches live from the REST API on appear (`ComboListView.load()`, `FilterMenuView.loadCounts()`), and every favourite/landed toggle is a live API call that silently no-ops on failure with no retry. If the Watch has no network reachability at that moment (e.g. the paired iPhone is in Airplane Mode and the Watch has no independent WiFi/cellular connection of its own), the app shows an error and nothing works — no browsing previously-seen combos, no queued changes, nothing syncs later.

Goal: the Watch should show the last-successfully-fetched combo lists when offline, let the user keep toggling favourite/landed while offline, and sync those changes to the backend automatically once connectivity returns — without requiring a manual "sync now" action.

## Non-goals

Everything the original Watch app spec already excluded remains excluded — this is additive, not an expansion of *what* the Watch can do, only of *when* it keeps working:
- No offline support for generating, building, editing, or rating combos (none of these exist on the Watch at all, online or offline).
- No admin features.
- No background refresh or push-triggered sync — sync only happens opportunistically while the app is foregrounded and making its own API calls (see "Sync trigger" below). No `NWPathMonitor`, no background tasks, no watchOS background refresh entitlements.
- No manual "Sync now" button or dedicated sync-status screen — the UI is limited to a small offline indicator and a pending-count banner (see "UI" below).
- No conflict resolution beyond replaying queued actions in order. This is safe because the two only offline-capable write endpoints (`POST`/`DELETE /api/combos/{id}/favourite` and `POST`/`DELETE /api/combos/{id}/complete`) are already fully idempotent server-side (confirmed by reading `UserFavouriteRepository.AddAsync`/`RemoveAsync` — `AddAsync` checks existence before inserting, `RemoveAsync` no-ops if the row doesn't exist), so replaying a stale or duplicate toggle is always safe.

## Architecture

### New abstraction: `ComboRepository`

`mobile/ios/Watch App Watch App/Offline/ComboRepository.swift` (new). Currently `ComboFilter.fetch()` (in `FilterMenuView.swift`) and `ComboListView`'s toggle methods call `APIClient` directly — there's no seam to insert caching or offline fallback. `ComboRepository` becomes the single thing Watch UI code talks to for combo data instead:

```swift
struct ComboListResult {
    let combos: [Combo]
    let isFromCache: Bool
}

final class ComboRepository {
    static let shared = ComboRepository()

    func loadPublic() async throws -> ComboListResult
    func loadMine() async throws -> ComboListResult
    func loadFavourites() async throws -> ComboListResult

    /// Merges loadPublic()+loadMine(), same dedupe-by-id (mine wins) as
    /// today's APIClient.getAllCombos(). Throws only if BOTH sub-loads throw
    /// (no cache for either); if one succeeds (live or cached) and the other
    /// throws, the merge still throws — a partial "All" list silently
    /// missing every Public or every Mine combo would be more misleading
    /// than an error. isFromCache is true if either sub-load came from cache.
    func loadAll() async throws -> ComboListResult

    /// loadAll() filtered to isCompleted — same throws/isFromCache behavior.
    func loadDone() async throws -> ComboListResult

    /// Applies the toggle optimistically to ComboCacheStore, attempts the live
    /// call, and returns the resulting Combo (with its flag(s) already
    /// flipped) so the caller can patch its own local list state — see
    /// "View-side state update" below. Never throws: a network failure just
    /// means the optimistic Combo is returned and an action was queued; a
    /// real API failure rolls the optimistic change back in the cache and
    /// returns the original (unchanged) Combo.
    func toggleFavourite(_ combo: Combo) async -> Combo
    func toggleDone(_ combo: Combo) async -> Combo
}
```

#### View-side state update

`ComboRepository` mutating `ComboCacheStore` doesn't, by itself, update `ComboListView`'s own `@State private var combos: [Combo]` — that's a separate in-memory array populated once by `load()`. So `ComboListView.toggleFavourite`/`toggleDone` (rewritten to call `ComboRepository` instead of `APIClient` directly) take the returned `Combo` and patch their local array directly: find the entry with matching `id` and replace it with the returned one. This is the same "mutate local state" approach the original v1 design deliberately avoided (its comment reads *"refetch rather than mutate local state — see design doc"*) — that avoidance made sense when there was no cache to keep in sync with; now that there's a persistent cache backing every list, a live refetch isn't even possible while offline, so local mutation is both necessary and (since the returned `Combo` came from the same optimistic-update path that updated the cache) consistent with it.

One extra step for the Favourites screen specifically: since unfavouriting changes *membership* in that list (not just a flag), `ComboListView` additionally removes the row from its local array when `filter == .favourites && !returnedCombo.isFavourited` — mirroring what a live re-fetch of `GET /combos/favourites` would return.

Each `load*` method: try the live `APIClient` call first. On success, write the result into `ComboCacheStore` (with a fresh timestamp), trigger nothing extra (the flush hook lives in `APIClient`, see below), and return `ComboListResult(combos: liveResult, isFromCache: false)`. On failure:
- If the error is a `URLError` (network-level — no connection, timeout, DNS failure, etc.) or any non-`APIError` thrown by `URLSession`, **and** `ComboCacheStore` has a cached value for that list, fall back to it and return `ComboListResult(combos: cached, isFromCache: true)`.
- If the error is a `URLError` and there is **no** cached value yet (never been online for this list), **rethrow the original error** rather than returning an empty result. This matters: `ComboListView.load()` already distinguishes "network error, show a retry-able error state" from "call succeeded, list is genuinely empty, show a friendly empty state" purely by whether an error was thrown. Swallowing the error into an empty `ComboListResult` here would make a true "can't reach the server, nothing saved yet" case render as the wrong empty state (e.g. "No favourites yet" instead of "Check your connection and try again") — so `ComboRepository` must only ever return a value when it actually has something (live or cached) to show, and throw in every other case, preserving `ComboListView`'s existing catch-based distinction unchanged.
- If the error is `APIError.unauthorized`, propagate it unchanged (existing `needsReconnect` handling in `ComboListView`/`FilterMenuView` stays exactly as it is today — no cache fallback for an auth failure, since an invalid/rotated token could mean the logged-in account changed on the phone, and showing a previous account's cached data would be actively wrong, not just stale).
- Any other `APIError` (server error, decoding failure): propagate unchanged, no cache fallback (these aren't connectivity problems — showing stale data would hide a real, non-retriable-by-waiting error).

`FilterMenuView.loadCounts()` is rewritten to go through `ComboRepository.loadPublic()`/`loadMine()`/`loadFavourites()` instead of calling `APIClient` directly, so its counts also fall back to cache offline instead of silently showing no counts.

### Caching: `ComboCacheStore`

`mobile/ios/Watch App Watch App/Offline/ComboCacheStore.swift` (new). A small `Codable`-backed store, following this codebase's existing hand-rolled-wrapper convention (`KeychainStore`, `APIClient` — no CoreData/SwiftData, no third-party persistence library):

```swift
struct ComboCache: Codable {
    var publicCombos: [Combo] = []
    var mineCombos: [Combo] = []
    var favouriteCombos: [Combo] = []
    var publicUpdatedAt: Date?
    var mineUpdatedAt: Date?
    var favouritesUpdatedAt: Date?
}

final class ComboCacheStore {
    static let shared = ComboCacheStore()

    private var cache: ComboCache  // loaded from disk on init, mutated in memory, written back on every change

    func read() -> ComboCache
    func writePublic(_ combos: [Combo])
    func writeMine(_ combos: [Combo])
    func writeFavourites(_ combos: [Combo])

    /// Applies an optimistic favourite/done toggle to every cached list the
    /// combo currently appears in. For favourite specifically, also adds/
    /// removes the combo from the cached Favourites list itself (real
    /// list-membership, not just a flag) — added copy carries isFavourited
    /// = true; on unfavourite the entry is removed from favouriteCombos
    /// entirely, matching what GET /combos/favourites would return.
    func applyFavouriteToggle(comboId: String, isFavourited: Bool, combo: Combo)
    func applyDoneToggle(comboId: String, isCompleted: Bool)

    /// Clears all cached lists and timestamps — called when the logged-in
    /// user changes (see "Account switching" below).
    func clear()
}
```

Persisted as a single JSON file (`combo_cache.json`) in the Watch app's Application Support directory (`FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)`, creating the directory if needed) via `Codable` + `JSONEncoder`/`JSONDecoder`. A single file (not one per list) keeps writes atomic-enough for this app's scale (at most ~150 combos total across three lists) and avoids partial-state races between files.

### Offline writes: `OfflineSyncQueue`

`mobile/ios/Watch App Watch App/Offline/OfflineSyncQueue.swift` (new):

```swift
enum PendingActionKind: String, Codable {
    case favourite, unfavourite, complete, uncomplete
}

struct PendingAction: Codable, Identifiable {
    let id: UUID
    let comboId: String
    let kind: PendingActionKind
    let createdAt: Date
}

final class OfflineSyncQueue {
    static let shared = OfflineSyncQueue()

    private(set) var pending: [PendingAction]  // loaded from disk on init
    private var isFlushing = false

    /// Enqueues an action, replacing any existing queued action for the same
    /// (comboId, category) pair — favourite/unfavourite is one category,
    /// complete/uncomplete is the other — so only the latest desired end
    /// state per combo per action-type is ever queued, not a stack of
    /// intermediate toggles.
    func enqueue(_ action: PendingAction)

    var count: Int { pending.count }

    /// Replays queued actions against the API in order. Called opportunistically
    /// (see APIClient hook below) — guarded against concurrent/recursive
    /// invocation via isFlushing. Stops (leaving the rest queued) on the first
    /// network-level failure. On APIError.unauthorized, stops and marks
    /// WatchAuthStore.needsReconnect. On a definitive rejection for a single
    /// action (e.g. combo deleted, 404/KeyNotFoundException), drops just that
    /// action and continues with the rest.
    func flushIfNeeded() async
}
```

Persisted the same way as `ComboCacheStore`, in its own file (`pending_actions.json`) — kept separate from the read cache so a problem with one can never affect the other (a corrupted cache file should never risk losing queued user actions, and vice versa).

`ComboRepository.toggleFavourite`/`toggleDone` are the only callers of `enqueue` — they call it exactly when the live API call throws a `URLError` (see "Architecture" above).

### Sync trigger

Hooked into `APIClient.send`/`sendNoBody`'s existing success path (both already funnel every request through these two methods): immediately after a `(200...299)` response, fire `Task { await OfflineSyncQueue.shared.flushIfNeeded() }` (not awaited by the caller, so it never blocks or delays the response that triggered it). `isFlushing` prevents this from recursing into itself when the flush's own replayed calls succeed and would otherwise trigger another flush.

This means: any successful live fetch anywhere in the app (opening the filter menu, opening a list, a toggle that happens to succeed live) opportunistically drains the queue. No explicit "sync" action, no background monitoring — matches the original Watch app spec's "no background refresh in v1" philosophy, just extended to cover write retries too.

### Account switching

`WatchAuthStore.apply(context:)` currently overwrites `token`/`userName` unconditionally whenever a new context arrives from the phone. Add one check: if the incoming `userName` differs from the previously-stored one (and the previous one was non-nil), call `ComboCacheStore.shared.clear()` and drop any queued `OfflineSyncQueue` actions before applying the new token. Prevents a previous account's cached combos or queued toggles from lingering after a different account logs in on the paired iPhone.

## UI

- `ComboListView`: when `ComboListResult.isFromCache == true`, a small row at the top of the `List` reading "Offline · showing saved data" (muted/secondary style, no icon needed — matches this codebase's existing lightweight `ContentUnavailableView`-style empty states rather than introducing a new visual language).
- `FilterMenuView`: when `OfflineSyncQueue.shared.count > 0`, a small banner row at the top of the filter list reading "N change(s) will sync automatically" (singular/plural per count).
- No other UI changes. `ComboDetailView` needs no changes at all — it already just renders whatever `Combo` object was passed to it via navigation (from an already-loaded, possibly-cached list), so it automatically reflects cached/optimistic state with zero new code.

## Error handling

Builds directly on the existing error model (`APIError.unauthorized` / `.server` / `.decoding`, plus raw `URLError` for network-level failures) rather than introducing a new one:

| Situation | Behavior |
|---|---|
| Live fetch fails, network-level error, cache available | Fall back to cache, `isFromCache = true` |
| Live fetch fails, network-level error, no cache | Existing empty/error state (unchanged) |
| Live fetch fails, 401 | Existing "reconnect on iPhone" state (unchanged), no cache fallback |
| Live fetch fails, other server/decoding error | Existing retry-able error state (unchanged), no cache fallback |
| Toggle fails, network-level error | Optimistic update kept, action enqueued |
| Toggle fails, 401 | Optimistic update rolled back, existing reconnect state shown |
| Toggle fails, other server error | Optimistic update rolled back, existing best-effort silent-fail behavior (matches today) |
| Queue flush hits network error | Flush stops, remaining actions stay queued |
| Queue flush hits 401 | Flush stops, remaining actions stay queued, reconnect state shown |
| Queue flush hits a rejected single action (e.g. combo deleted) | That action is dropped, flush continues with the rest |

## Testing

Same situation as the rest of the iOS/watchOS codebase — no unit test target exists for the Watch app (per the original Watch app spec's "Testing" section). Verification stays manual: run on a paired Watch Simulator, toggle favourite/landed with the Simulator's network conditioning set to "offline" (or via `Network Link Conditioner`), confirm the change is reflected immediately and the banner/offline row appear, then restore connectivity and confirm the change appears on the phone/web without any manual action. Also verify: cold-launching the Watch app with no connectivity but a previously-populated cache shows the cached lists; logging into a different account on the phone clears a previous account's cache.
