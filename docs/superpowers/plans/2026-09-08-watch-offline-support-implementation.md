# Apple Watch Offline Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the FreestyleCombo Apple Watch app show cached combo lists and queue favourite/landed toggles when offline, syncing automatically once connectivity returns.

**Architecture:** Three new files under `mobile/ios/Watch App Watch App/Offline/` (`ComboCacheStore`, `OfflineSyncQueue`, `ComboRepository`) sit between the existing `APIClient` and the two screens (`FilterMenuView`, `ComboListView`), which are rewired to go through `ComboRepository` instead of calling `APIClient` directly. `APIClient` gets one small addition: a fire-and-forget queue-flush trigger on every successful call.

**Tech Stack:** Swift, SwiftUI, watchOS 10+, `Codable`/`JSONEncoder`/`JSONDecoder` for on-disk persistence (no CoreData/SwiftData, matching this codebase's existing hand-rolled-wrapper style).

**Spec:** `docs/superpowers/specs/2026-09-08-watch-offline-support-design.md` — read it for full rationale; this plan implements it exactly.

**Important project-structure note:** The Watch App target (`mobile/ios/Runner.xcodeproj`, target "Watch App Watch App") uses Xcode's `PBXFileSystemSynchronizedRootGroup` feature (confirmed by reading `project.pbxproj`) — **any new `.swift` file placed anywhere under `mobile/ios/Watch App Watch App/` is automatically included in the build.** Unlike the Runner (iOS) target elsewhere in this project, **no `project.pbxproj` editing is needed** for new files in this plan. Do not attempt to manually add build-file/file-reference entries — they don't exist for this target and aren't needed.

**Build verification command** (use after every task — confirmed working during planning):
```bash
cd mobile && xcodebuild -workspace ios/Runner.xcworkspace -scheme "Watch App Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" -configuration Debug build
```
Expected: output ends with `** BUILD SUCCEEDED **`. If it fails with a "No space left on device" or native-assets/`NativeAssetsManifest.json` error, run `flutter clean && flutter pub get && (cd ios && pod install)` from `mobile/` first (a known stale-cache issue documented in `CLAUDE.md`'s release-pipeline gotchas), then retry the build.

There is no unit test target for the Watch app (confirmed — matches the precedent set by `docs/superpowers/specs/2026-09-03-watch-app-design.md`'s "Testing" section). Every task below ends with the build-verification command instead of a test run.

---

### Task 1: Make `Combo`'s flags mutable, add `ComboCacheStore`

**Files:**
- Modify: `mobile/ios/Watch App Watch App/Models/ComboModels.swift`
- Create: `mobile/ios/Watch App Watch App/Offline/ComboCacheStore.swift`

- [ ] **Step 1: Make `isFavourited`/`isCompleted` mutable**

In `mobile/ios/Watch App Watch App/Models/ComboModels.swift`, find:

```swift
struct Combo: Codable, Identifiable {
    let id: String
    let ownerId: String
    let ownerUserName: String?
    let name: String?
    let totalDifficulty: Double
    let trickCount: Int
    let visibility: String?
    let displayText: String
    let tricks: [ComboTrick]?
    let isFavourited: Bool
    let isCompleted: Bool
```

Replace with:

```swift
struct Combo: Codable, Identifiable {
    let id: String
    let ownerId: String
    let ownerUserName: String?
    let name: String?
    let totalDifficulty: Double
    let trickCount: Int
    let visibility: String?
    let displayText: String
    let tricks: [ComboTrick]?
    var isFavourited: Bool
    var isCompleted: Bool
```

(Only these two fields change from `let` to `var` — everything else in the file is unchanged. This lets the offline layer build a locally-mutated copy of a `Combo` after an optimistic toggle, without needing separate `withFavourited`/`withCompleted` helper methods.)

- [ ] **Step 2: Create `ComboCacheStore.swift`**

Create `mobile/ios/Watch App Watch App/Offline/ComboCacheStore.swift`:

```swift
// mobile/ios/Watch App/Offline/ComboCacheStore.swift
import Foundation

struct ComboCache: Codable {
    var publicCombos: [Combo] = []
    var mineCombos: [Combo] = []
    var favouriteCombos: [Combo] = []
    var publicUpdatedAt: Date?
    var mineUpdatedAt: Date?
    var favouritesUpdatedAt: Date?
}

/// Persists the last-successfully-fetched Public/Mine/Favourites combo lists
/// to disk so the Watch app can show them when offline. A single JSON file
/// (not one per list) keeps writes simple at this app's scale (at most ~150
/// combos total across the three lists). See
/// docs/superpowers/specs/2026-09-08-watch-offline-support-design.md.
final class ComboCacheStore {
    static let shared = ComboCacheStore()

    private var cache: ComboCache
    private let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        fileURL = dir.appendingPathComponent("combo_cache.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(ComboCache.self, from: data) {
            cache = decoded
        } else {
            cache = ComboCache()
        }
    }

    func read() -> ComboCache { cache }

    func writePublic(_ combos: [Combo]) {
        cache.publicCombos = combos
        cache.publicUpdatedAt = Date()
        persist()
    }

    func writeMine(_ combos: [Combo]) {
        cache.mineCombos = combos
        cache.mineUpdatedAt = Date()
        persist()
    }

    func writeFavourites(_ combos: [Combo]) {
        cache.favouriteCombos = combos
        cache.favouritesUpdatedAt = Date()
        persist()
    }

    /// Flips isFavourited on every cached entry with this id (Public/Mine),
    /// and adds/removes the entry from the cached Favourites list itself to
    /// match what GET /combos/favourites would return — the passed-in combo
    /// must already carry the new isFavourited value.
    func applyFavouriteToggle(comboId: String, isFavourited: Bool, combo: Combo) {
        cache.publicCombos = cache.publicCombos.map { c in
            var c = c
            if c.id == comboId { c.isFavourited = isFavourited }
            return c
        }
        cache.mineCombos = cache.mineCombos.map { c in
            var c = c
            if c.id == comboId { c.isFavourited = isFavourited }
            return c
        }
        if isFavourited {
            if !cache.favouriteCombos.contains(where: { $0.id == comboId }) {
                cache.favouriteCombos.append(combo)
            }
        } else {
            cache.favouriteCombos.removeAll { $0.id == comboId }
        }
        persist()
    }

    /// Flips isCompleted on every cached entry with this id (Public/Mine/
    /// Favourites) — completion doesn't change list membership anywhere.
    func applyDoneToggle(comboId: String, isCompleted: Bool) {
        cache.publicCombos = cache.publicCombos.map { c in
            var c = c
            if c.id == comboId { c.isCompleted = isCompleted }
            return c
        }
        cache.mineCombos = cache.mineCombos.map { c in
            var c = c
            if c.id == comboId { c.isCompleted = isCompleted }
            return c
        }
        cache.favouriteCombos = cache.favouriteCombos.map { c in
            var c = c
            if c.id == comboId { c.isCompleted = isCompleted }
            return c
        }
        persist()
    }

    /// Clears all cached lists and timestamps — called when the logged-in
    /// user changes (see WatchAuthStore.apply(context:)).
    func clear() {
        cache = ComboCache()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 3: Verify it builds**

Run:
```bash
cd mobile && xcodebuild -workspace ios/Runner.xcworkspace -scheme "Watch App Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" -configuration Debug build
```
Expected: `** BUILD SUCCEEDED **`. (`ComboCacheStore` isn't used by anything yet, so this just confirms the new file and the `Combo` model change compile cleanly together.)

- [ ] **Step 4: Commit**

```bash
git add "mobile/ios/Watch App Watch App/Models/ComboModels.swift" "mobile/ios/Watch App Watch App/Offline/ComboCacheStore.swift"
git commit -m "Add ComboCacheStore for offline combo caching"
```

---

### Task 2: Add `OfflineSyncQueue`

**Files:**
- Create: `mobile/ios/Watch App Watch App/Offline/OfflineSyncQueue.swift`

- [ ] **Step 1: Create the file**

Create `mobile/ios/Watch App Watch App/Offline/OfflineSyncQueue.swift`:

```swift
// mobile/ios/Watch App/Offline/OfflineSyncQueue.swift
import Foundation

enum PendingActionKind: String, Codable {
    case favourite, unfavourite, complete, uncomplete

    /// Groups favourite/unfavourite as one category and complete/uncomplete
    /// as another, so enqueuing a new action for the same combo+category
    /// replaces any existing queued one instead of stacking redundant
    /// intermediate toggles — only the latest desired end state per combo
    /// per action-type is ever queued.
    var category: String {
        switch self {
        case .favourite, .unfavourite: return "favourite"
        case .complete, .uncomplete: return "complete"
        }
    }
}

struct PendingAction: Codable, Identifiable {
    let id: UUID
    let comboId: String
    let kind: PendingActionKind
    let createdAt: Date
}

/// Persists a queue of favourite/landed toggles made while offline and
/// replays them against the API once connectivity returns. See
/// docs/superpowers/specs/2026-09-08-watch-offline-support-design.md.
final class OfflineSyncQueue {
    static let shared = OfflineSyncQueue()

    private(set) var pending: [PendingAction]
    private var isFlushing = false
    private let fileURL: URL

    var count: Int { pending.count }

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        fileURL = dir.appendingPathComponent("pending_actions.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([PendingAction].self, from: data) {
            pending = decoded
        } else {
            pending = []
        }
    }

    func enqueue(comboId: String, kind: PendingActionKind) {
        pending.removeAll { $0.comboId == comboId && $0.kind.category == kind.category }
        pending.append(PendingAction(id: UUID(), comboId: comboId, kind: kind, createdAt: Date()))
        persist()
    }

    func clear() {
        pending = []
        persist()
    }

    /// Replays queued actions against the API in order. Guarded against
    /// concurrent/recursive invocation via isFlushing — a successful replay
    /// call goes through APIClient, whose own success path also calls this
    /// method (see APIClient.triggerSyncFlush), so without the guard this
    /// would recurse into itself.
    func flushIfNeeded() async {
        guard !isFlushing, !pending.isEmpty else { return }
        isFlushing = true
        defer { isFlushing = false }

        while let action = pending.first {
            do {
                try await replay(action)
                pending.removeFirst()
                persist()
            } catch APIError.unauthorized {
                await MainActor.run { WatchAuthStore.shared.markReconnectNeeded() }
                return
            } catch is URLError {
                // Network still down — stop, leave this and the rest queued for next time.
                return
            } catch {
                // Definitive rejection (e.g. combo deleted) — drop just this one, keep going.
                pending.removeFirst()
                persist()
            }
        }
    }

    private func replay(_ action: PendingAction) async throws {
        switch action.kind {
        case .favourite: try await APIClient.shared.addFavourite(id: action.comboId)
        case .unfavourite: try await APIClient.shared.removeFavourite(id: action.comboId)
        case .complete: try await APIClient.shared.markCompleted(id: action.comboId)
        case .uncomplete: try await APIClient.shared.unmarkCompleted(id: action.comboId)
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 2: Verify it builds**

Run:
```bash
cd mobile && xcodebuild -workspace ios/Runner.xcworkspace -scheme "Watch App Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" -configuration Debug build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "mobile/ios/Watch App Watch App/Offline/OfflineSyncQueue.swift"
git commit -m "Add OfflineSyncQueue for queuing and replaying offline toggles"
```

---

### Task 3: Add `ComboRepository`

**Files:**
- Create: `mobile/ios/Watch App Watch App/Offline/ComboRepository.swift`

- [ ] **Step 1: Create the file**

Create `mobile/ios/Watch App Watch App/Offline/ComboRepository.swift`:

```swift
// mobile/ios/Watch App/Offline/ComboRepository.swift
import Foundation

struct ComboListResult {
    let combos: [Combo]
    let isFromCache: Bool
}

/// The single place Watch UI code goes for combo data — wraps APIClient with
/// a try-live-then-fall-back-to-cache read path and an optimistic-update-
/// then-queue-or-rollback write path. See
/// docs/superpowers/specs/2026-09-08-watch-offline-support-design.md.
final class ComboRepository {
    static let shared = ComboRepository()

    private init() {}

    /// Throws only when the live call fails AND there's no cached fallback —
    /// this preserves ComboListView's existing distinction between "network
    /// error, show a retry-able error state" and "call succeeded, list is
    /// genuinely empty, show a friendly empty state." Never returns an empty
    /// result to paper over a real connectivity failure.
    func loadPublic() async throws -> ComboListResult {
        do {
            let combos = try await APIClient.shared.getPublicCombos()
            ComboCacheStore.shared.writePublic(combos)
            return ComboListResult(combos: combos, isFromCache: false)
        } catch let error as URLError {
            let cached = ComboCacheStore.shared.read()
            if cached.publicUpdatedAt != nil {
                return ComboListResult(combos: cached.publicCombos, isFromCache: true)
            }
            throw error
        }
    }

    func loadMine() async throws -> ComboListResult {
        do {
            let combos = try await APIClient.shared.getMyCombos()
            ComboCacheStore.shared.writeMine(combos)
            return ComboListResult(combos: combos, isFromCache: false)
        } catch let error as URLError {
            let cached = ComboCacheStore.shared.read()
            if cached.mineUpdatedAt != nil {
                return ComboListResult(combos: cached.mineCombos, isFromCache: true)
            }
            throw error
        }
    }

    func loadFavourites() async throws -> ComboListResult {
        do {
            let combos = try await APIClient.shared.getFavourites()
            ComboCacheStore.shared.writeFavourites(combos)
            return ComboListResult(combos: combos, isFromCache: false)
        } catch let error as URLError {
            let cached = ComboCacheStore.shared.read()
            if cached.favouritesUpdatedAt != nil {
                return ComboListResult(combos: cached.favouriteCombos, isFromCache: true)
            }
            throw error
        }
    }

    /// Merges loadPublic()+loadMine(), same dedupe-by-id (mine wins) as
    /// APIClient.getAllCombos(). A 401 from either side propagates
    /// immediately regardless of the other's outcome (a stale/invalid token
    /// affects every endpoint the same way, so there's no reason to wait on
    /// the other call). Otherwise, throws only if BOTH sub-loads throw — a
    /// partial "All" list silently missing every Public or every Mine combo
    /// would be more misleading than an error. isFromCache is true if either
    /// sub-load came from cache.
    func loadAll() async throws -> ComboListResult {
        async let publicResult = loadPublic()
        async let mineResult = loadMine()

        var pub: ComboListResult?
        var mine: ComboListResult?
        var pubError: Error?
        var mineError: Error?

        do {
            pub = try await publicResult
        } catch APIError.unauthorized {
            throw APIError.unauthorized
        } catch {
            pubError = error
        }

        do {
            mine = try await mineResult
        } catch APIError.unauthorized {
            throw APIError.unauthorized
        } catch {
            mineError = error
        }

        if pub == nil && mine == nil {
            throw mineError ?? pubError ?? APIError.server("No data available")
        }

        var merged: [String: Combo] = [:]
        for c in mine?.combos ?? [] { merged[c.id] = c }
        for c in pub?.combos ?? [] where merged[c.id] == nil { merged[c.id] = c }

        let isFromCache = (pub?.isFromCache ?? true) || (mine?.isFromCache ?? true)
        return ComboListResult(combos: Array(merged.values), isFromCache: isFromCache)
    }

    /// loadAll() filtered to isCompleted — same throws/isFromCache behavior.
    func loadDone() async throws -> ComboListResult {
        let all = try await loadAll()
        return ComboListResult(combos: all.combos.filter(\.isCompleted), isFromCache: all.isFromCache)
    }

    /// Applies the toggle optimistically to ComboCacheStore, attempts the
    /// live call, and returns the resulting Combo (flag already flipped) so
    /// the caller can patch its own local list state. Never throws: a
    /// network failure just means the optimistic Combo is returned and an
    /// action is queued for later; a real API failure (e.g. 401) rolls the
    /// optimistic change back in the cache and returns the original,
    /// unchanged Combo.
    func toggleFavourite(_ combo: Combo) async -> Combo {
        let newValue = !combo.isFavourited
        var updated = combo
        updated.isFavourited = newValue
        ComboCacheStore.shared.applyFavouriteToggle(comboId: combo.id, isFavourited: newValue, combo: updated)

        do {
            if newValue {
                try await APIClient.shared.addFavourite(id: combo.id)
            } else {
                try await APIClient.shared.removeFavourite(id: combo.id)
            }
            return updated
        } catch is URLError {
            OfflineSyncQueue.shared.enqueue(comboId: combo.id, kind: newValue ? .favourite : .unfavourite)
            return updated
        } catch {
            ComboCacheStore.shared.applyFavouriteToggle(comboId: combo.id, isFavourited: combo.isFavourited, combo: combo)
            return combo
        }
    }

    func toggleDone(_ combo: Combo) async -> Combo {
        let newValue = !combo.isCompleted
        var updated = combo
        updated.isCompleted = newValue
        ComboCacheStore.shared.applyDoneToggle(comboId: combo.id, isCompleted: newValue)

        do {
            if newValue {
                try await APIClient.shared.markCompleted(id: combo.id)
            } else {
                try await APIClient.shared.unmarkCompleted(id: combo.id)
            }
            return updated
        } catch is URLError {
            OfflineSyncQueue.shared.enqueue(comboId: combo.id, kind: newValue ? .complete : .uncomplete)
            return updated
        } catch {
            ComboCacheStore.shared.applyDoneToggle(comboId: combo.id, isCompleted: combo.isCompleted)
            return combo
        }
    }
}
```

- [ ] **Step 2: Verify it builds**

Run:
```bash
cd mobile && xcodebuild -workspace ios/Runner.xcworkspace -scheme "Watch App Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" -configuration Debug build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "mobile/ios/Watch App Watch App/Offline/ComboRepository.swift"
git commit -m "Add ComboRepository tying APIClient, cache, and sync queue together"
```

---

### Task 4: Wire the opportunistic sync-flush trigger into `APIClient`

**Files:**
- Modify: `mobile/ios/Watch App Watch App/Networking/APIClient.swift`

- [ ] **Step 1: Add the trigger call and helper method**

In `mobile/ios/Watch App Watch App/Networking/APIClient.swift`, find:

```swift
    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.server("No response") }
        if http.statusCode == 401 {
            await MainActor.run { WatchAuthStore.shared.markReconnectNeeded() }
            throw APIError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.server(errorMessage(from: data, statusCode: http.statusCode))
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func sendNoBody(_ request: URLRequest) async throws {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.server("No response") }
        if http.statusCode == 401 {
            await MainActor.run { WatchAuthStore.shared.markReconnectNeeded() }
            throw APIError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.server(errorMessage(from: data, statusCode: http.statusCode))
        }
    }
```

Replace with:

```swift
    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.server("No response") }
        if http.statusCode == 401 {
            await MainActor.run { WatchAuthStore.shared.markReconnectNeeded() }
            throw APIError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.server(errorMessage(from: data, statusCode: http.statusCode))
        }
        triggerSyncFlush()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private func sendNoBody(_ request: URLRequest) async throws {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.server("No response") }
        if http.statusCode == 401 {
            await MainActor.run { WatchAuthStore.shared.markReconnectNeeded() }
            throw APIError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.server(errorMessage(from: data, statusCode: http.statusCode))
        }
        triggerSyncFlush()
    }

    /// Opportunistically drains OfflineSyncQueue whenever any API call
    /// succeeds — the "sync trigger" from the offline-support design.
    /// Fire-and-forget (not awaited) so it never delays the response that
    /// triggered it; OfflineSyncQueue's own isFlushing guard prevents this
    /// from recursing into itself when a replayed call succeeds and hits
    /// this same code path again.
    private func triggerSyncFlush() {
        Task { await OfflineSyncQueue.shared.flushIfNeeded() }
    }
```

- [ ] **Step 2: Verify it builds**

Run:
```bash
cd mobile && xcodebuild -workspace ios/Runner.xcworkspace -scheme "Watch App Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" -configuration Debug build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "mobile/ios/Watch App Watch App/Networking/APIClient.swift"
git commit -m "Trigger opportunistic offline-queue flush on every successful API call"
```

---

### Task 5: Clear cache and queue on account switch

**Files:**
- Modify: `mobile/ios/Watch App Watch App/Auth/WatchAuthStore.swift`

- [ ] **Step 1: Add the account-switch check**

In `mobile/ios/Watch App Watch App/Auth/WatchAuthStore.swift`, find:

```swift
    private func apply(context: [String: Any]) {
        DispatchQueue.main.async {
            guard let jwt = context["jwt"] as? String, !jwt.isEmpty else { return }
            KeychainStore.set(jwt, forKey: jwtKey)
            self.token = jwt
            self.needsReconnect = false
            if let name = context["userName"] as? String {
                KeychainStore.set(name, forKey: userNameKey)
                self.userName = name
            }
        }
    }
```

Replace with:

```swift
    private func apply(context: [String: Any]) {
        DispatchQueue.main.async {
            guard let jwt = context["jwt"] as? String, !jwt.isEmpty else { return }
            // A different account logged in on the paired iPhone — drop this
            // account's cached combos and queued offline toggles so they
            // don't linger and show up under the new account.
            if let newName = context["userName"] as? String,
               let previousName = self.userName,
               newName != previousName {
                ComboCacheStore.shared.clear()
                OfflineSyncQueue.shared.clear()
            }
            KeychainStore.set(jwt, forKey: jwtKey)
            self.token = jwt
            self.needsReconnect = false
            if let name = context["userName"] as? String {
                KeychainStore.set(name, forKey: userNameKey)
                self.userName = name
            }
        }
    }
```

- [ ] **Step 2: Verify it builds**

Run:
```bash
cd mobile && xcodebuild -workspace ios/Runner.xcworkspace -scheme "Watch App Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" -configuration Debug build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "mobile/ios/Watch App Watch App/Auth/WatchAuthStore.swift"
git commit -m "Clear offline cache and queue when a different account logs in"
```

---

### Task 6: Rewire `FilterMenuView` through `ComboRepository`

**Files:**
- Modify: `mobile/ios/Watch App Watch App/Screens/FilterMenuView.swift`
- Modify: `mobile/ios/Watch App Watch App/Networking/APIClient.swift`

- [ ] **Step 1: Rewrite `ComboFilter.fetch()`**

In `mobile/ios/Watch App Watch App/Screens/FilterMenuView.swift`, find:

```swift
    func fetch() async throws -> [Combo] {
        switch self {
        case .all: return try await APIClient.shared.getAllCombos()
        case .pub: return try await APIClient.shared.getPublicCombos()
        case .mine: return try await APIClient.shared.getMyCombos()
        case .favourites: return try await APIClient.shared.getFavourites()
        case .done:
            // No dedicated "landed" endpoint — filter the merged All list
            // client-side, matching combos_screen.dart's _matchesDoneFilter.
            return try await APIClient.shared.getAllCombos().filter(\.isCompleted)
        }
    }
```

Replace with:

```swift
    func fetch() async throws -> ComboListResult {
        switch self {
        case .all: return try await ComboRepository.shared.loadAll()
        case .pub: return try await ComboRepository.shared.loadPublic()
        case .mine: return try await ComboRepository.shared.loadMine()
        case .favourites: return try await ComboRepository.shared.loadFavourites()
        case .done: return try await ComboRepository.shared.loadDone()
        }
    }
```

- [ ] **Step 2: Rewrite `loadCounts()` to go through `ComboRepository`**

Find:

```swift
    private func loadCounts() async {
        async let publicCombos = APIClient.shared.getPublicCombos()
        async let mineCombos = APIClient.shared.getMyCombos()
        async let favouriteCombos = APIClient.shared.getFavourites()

        guard
            let pub = try? await publicCombos,
            let mine = try? await mineCombos,
            let favs = try? await favouriteCombos
        else { return }

        var merged: [String: Combo] = [:]
        for c in mine { merged[c.id] = c }
        for c in pub where merged[c.id] == nil { merged[c.id] = c }
        let all = Array(merged.values)

        counts[.all] = all.count
        counts[.pub] = pub.count
        counts[.mine] = mine.count
        counts[.favourites] = favs.count
        counts[.done] = all.filter(\.isCompleted).count
    }
```

Replace with:

```swift
    private func loadCounts() async {
        async let publicResult = ComboRepository.shared.loadPublic()
        async let mineResult = ComboRepository.shared.loadMine()
        async let favouritesResult = ComboRepository.shared.loadFavourites()

        guard
            let pub = try? await publicResult,
            let mine = try? await mineResult,
            let favs = try? await favouritesResult
        else { return }

        var merged: [String: Combo] = [:]
        for c in mine.combos { merged[c.id] = c }
        for c in pub.combos where merged[c.id] == nil { merged[c.id] = c }
        let all = Array(merged.values)

        counts[.all] = all.count
        counts[.pub] = pub.combos.count
        counts[.mine] = mine.combos.count
        counts[.favourites] = favs.combos.count
        counts[.done] = all.filter(\.isCompleted).count
        pendingCount = OfflineSyncQueue.shared.count
    }
```

- [ ] **Step 3: Add the `pendingCount` state and the pending-actions banner**

Find:

```swift
struct FilterMenuView: View {
    @StateObject private var authStore = WatchAuthStore.shared
    @State private var counts: [ComboFilter: Int] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if authStore.needsReconnect {
                    ReconnectView()
                } else if authStore.token == nil {
                    ContentUnavailableView(
                        "Log in on your iPhone",
                        systemImage: "iphone",
                        description: Text("Open FreestyleCombo on your iPhone and log in first.")
                    )
                } else {
                    List(ComboFilter.allCases) { filter in
                        NavigationLink(value: filter) {
                            HStack {
                                Circle().fill(filter.dotColor).frame(width: 8, height: 8)
                                Text(filter.rawValue)
                                Spacer()
                                if let count = counts[filter] {
                                    Text("\(count)").foregroundStyle(.secondary).monospacedDigit()
                                }
                            }
                        }
                    }
                    .navigationDestination(for: ComboFilter.self) { filter in
                        ComboListView(filter: filter)
                    }
                    .task { await loadCounts() }
                }
            }
            .navigationTitle("Combos")
        }
    }
```

Replace with:

```swift
struct FilterMenuView: View {
    @StateObject private var authStore = WatchAuthStore.shared
    @State private var counts: [ComboFilter: Int] = [:]
    @State private var pendingCount = 0

    var body: some View {
        NavigationStack {
            Group {
                if authStore.needsReconnect {
                    ReconnectView()
                } else if authStore.token == nil {
                    ContentUnavailableView(
                        "Log in on your iPhone",
                        systemImage: "iphone",
                        description: Text("Open FreestyleCombo on your iPhone and log in first.")
                    )
                } else {
                    List {
                        if pendingCount > 0 {
                            Text(pendingCount == 1
                                 ? "1 change will sync automatically"
                                 : "\(pendingCount) changes will sync automatically")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(ComboFilter.allCases) { filter in
                            NavigationLink(value: filter) {
                                HStack {
                                    Circle().fill(filter.dotColor).frame(width: 8, height: 8)
                                    Text(filter.rawValue)
                                    Spacer()
                                    if let count = counts[filter] {
                                        Text("\(count)").foregroundStyle(.secondary).monospacedDigit()
                                    }
                                }
                            }
                        }
                    }
                    .navigationDestination(for: ComboFilter.self) { filter in
                        ComboListView(filter: filter)
                    }
                    .task { await loadCounts() }
                }
            }
            .navigationTitle("Combos")
        }
    }
```

- [ ] **Step 4: Remove the now-unused `APIClient.getAllCombos()`**

After Step 1 above, nothing calls `APIClient.shared.getAllCombos()` anymore — `ComboRepository.loadAll()` (Task 3) reimplements the same merge itself by calling `getPublicCombos()`/`getMyCombos()` separately (each needs its own cache-fallback handling before merging). Remove the now-dead method.

In `mobile/ios/Watch App Watch App/Networking/APIClient.swift`, find:

```swift
    /// "All" = every Public combo plus the caller's own combos regardless of
    /// visibility, merged and de-duplicated by id — mirrors combos_screen.dart's
    /// `_fetchAllCombined()` (mine wins on a collision, since it carries the
    /// full owner-context flags).
    func getAllCombos() async throws -> [Combo] {
        async let publicCombos = getPublicCombos()
        async let mineCombos = getMyCombos()
        var merged: [String: Combo] = [:]
        for c in try await mineCombos { merged[c.id] = c }
        for c in try await publicCombos where merged[c.id] == nil { merged[c.id] = c }
        return Array(merged.values)
    }

    private func mutate(_ path: String, method: String) async throws {
```

Replace with:

```swift
    private func mutate(_ path: String, method: String) async throws {
```

(This deletes the `getAllCombos()` method and its doc comment entirely — the `private func mutate` line stays, now immediately following `getFavourites()` instead of the removed method.)

- [ ] **Step 5: Verify it builds**

Run:
```bash
cd mobile && xcodebuild -workspace ios/Runner.xcworkspace -scheme "Watch App Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" -configuration Debug build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add "mobile/ios/Watch App Watch App/Screens/FilterMenuView.swift" "mobile/ios/Watch App Watch App/Networking/APIClient.swift"
git commit -m "Rewire FilterMenuView through ComboRepository, add pending-sync banner, remove unused getAllCombos()"
```

---

### Task 7: Rewire `ComboListView` through `ComboRepository`

**Files:**
- Modify: `mobile/ios/Watch App Watch App/Screens/ComboListView.swift`

- [ ] **Step 1: Add `isFromCache` state and the offline row**

In `mobile/ios/Watch App Watch App/Screens/ComboListView.swift`, find:

```swift
struct ComboListView: View {
    let filter: ComboFilter

    @StateObject private var authStore = WatchAuthStore.shared
    @State private var combos: [Combo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if authStore.needsReconnect {
                ContentUnavailableView(
                    "Reconnect needed",
                    systemImage: "iphone.and.arrow.forward",
                    description: Text("Open FreestyleCombo on your iPhone to reconnect.")
                )
            } else if isLoading {
                ProgressView()
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Couldn't load combos", systemImage: "wifi.slash")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Retry") { Task { await load() } }
                }
            } else if combos.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "list.bullet"
                )
            } else {
                List(combos) { combo in
                    NavigationLink(value: combo) {
                        ComboRow(combo: combo)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            Task { await toggleFavourite(combo) }
                        } label: {
                            Label("Favourite", systemImage: combo.isFavourited ? "heart.slash" : "heart")
                        }
                        .tint(.pink)
                    }
                    .swipeActions(edge: .trailing) {
                        // Same checkmark glyph either way — only the tint reflects
                        // current state (green landed, grey not), matching
                        // combo_card.dart's check_circle/check_circle_outline +
                        // green/faint pattern rather than swapping to an X.
                        Button {
                            Task { await toggleDone(combo) }
                        } label: {
                            Label("Landed", systemImage: combo.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        }
                        .tint(combo.isCompleted ? .green : .gray)
                    }
                }
            }
        }
        .navigationTitle(filter.rawValue)
        .navigationDestination(for: Combo.self) { combo in
            ComboDetailView(combo: combo)
        }
        .task { await load() }
    }
```

Replace with:

```swift
struct ComboListView: View {
    let filter: ComboFilter

    @StateObject private var authStore = WatchAuthStore.shared
    @State private var combos: [Combo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isFromCache = false

    var body: some View {
        Group {
            if authStore.needsReconnect {
                ContentUnavailableView(
                    "Reconnect needed",
                    systemImage: "iphone.and.arrow.forward",
                    description: Text("Open FreestyleCombo on your iPhone to reconnect.")
                )
            } else if isLoading {
                ProgressView()
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Couldn't load combos", systemImage: "wifi.slash")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Retry") { Task { await load() } }
                }
            } else if combos.isEmpty {
                ContentUnavailableView(
                    emptyTitle,
                    systemImage: "list.bullet"
                )
            } else {
                List {
                    if isFromCache {
                        Text("Offline · showing saved data")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(combos) { combo in
                        NavigationLink(value: combo) {
                            ComboRow(combo: combo)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await toggleFavourite(combo) }
                            } label: {
                                Label("Favourite", systemImage: combo.isFavourited ? "heart.slash" : "heart")
                            }
                            .tint(.pink)
                        }
                        .swipeActions(edge: .trailing) {
                            // Same checkmark glyph either way — only the tint reflects
                            // current state (green landed, grey not), matching
                            // combo_card.dart's check_circle/check_circle_outline +
                            // green/faint pattern rather than swapping to an X.
                            Button {
                                Task { await toggleDone(combo) }
                            } label: {
                                Label("Landed", systemImage: combo.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                            }
                            .tint(combo.isCompleted ? .green : .gray)
                        }
                    }
                }
            }
        }
        .navigationTitle(filter.rawValue)
        .navigationDestination(for: Combo.self) { combo in
            ComboDetailView(combo: combo)
        }
        .task { await load() }
    }
```

- [ ] **Step 2: Rewrite `load()`, remove `refresh()`, rewrite the toggle methods**

Find:

```swift
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            combos = try await filter.fetch()
        } catch APIError.unauthorized {
            errorMessage = nil // FilterMenuView's reconnect state takes over on the way back
        } catch {
            errorMessage = "Check your connection and try again."
        }
        isLoading = false
    }

    private func refresh() async {
        combos = (try? await filter.fetch()) ?? combos
    }

    private func toggleFavourite(_ combo: Combo) async {
        do {
            if combo.isFavourited {
                try await APIClient.shared.removeFavourite(id: combo.id)
            } else {
                try await APIClient.shared.addFavourite(id: combo.id)
            }
            await refresh() // refetch rather than mutate local state — see design doc
        } catch {
            // Best-effort action from a list row — a failed toggle just leaves
            // the row as it was; the user can retry the swipe.
        }
    }

    private func toggleDone(_ combo: Combo) async {
        do {
            if combo.isCompleted {
                try await APIClient.shared.unmarkCompleted(id: combo.id)
            } else {
                try await APIClient.shared.markCompleted(id: combo.id)
            }
            await refresh()
        } catch {
            // Same rationale as toggleFavourite.
        }
    }
}
```

Replace with:

```swift
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await filter.fetch()
            combos = result.combos
            isFromCache = result.isFromCache
        } catch APIError.unauthorized {
            errorMessage = nil // FilterMenuView's reconnect state takes over on the way back
        } catch {
            errorMessage = "Check your connection and try again."
        }
        isLoading = false
    }

    private func toggleFavourite(_ combo: Combo) async {
        let updated = await ComboRepository.shared.toggleFavourite(combo)
        applyLocalUpdate(updated)
    }

    private func toggleDone(_ combo: Combo) async {
        let updated = await ComboRepository.shared.toggleDone(combo)
        applyLocalUpdate(updated)
    }

    /// Patches the local combos array with ComboRepository's returned value
    /// instead of refetching — a live refetch isn't always possible while
    /// offline (the whole point of this feature), and the repository's
    /// optimistic update already reflects the correct end state either way.
    /// On the Favourites screen specifically, an unfavourite also removes
    /// the row, matching what a live re-fetch of GET /combos/favourites
    /// would return.
    private func applyLocalUpdate(_ updated: Combo) {
        if filter == .favourites && !updated.isFavourited {
            combos.removeAll { $0.id == updated.id }
        } else if let index = combos.firstIndex(where: { $0.id == updated.id }) {
            combos[index] = updated
        }
    }
}
```

- [ ] **Step 3: Verify it builds**

Run:
```bash
cd mobile && xcodebuild -workspace ios/Runner.xcworkspace -scheme "Watch App Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" -configuration Debug build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add "mobile/ios/Watch App Watch App/Screens/ComboListView.swift"
git commit -m "Rewire ComboListView through ComboRepository with optimistic local updates"
```

---

### Task 8: Document in CLAUDE.md, full verification pass

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add a subsection documenting offline support**

`CLAUDE.md` has no dedicated Apple Watch architecture section yet (confirmed by reading it — the Watch app is only mentioned in passing in "Production Deployment" and the "iOS release process" gotchas). Add a new, self-contained subsection at the end of the "Mobile — Flutter (Phase 3)" part of the file rather than inventing an anchor that doesn't exist.

In `CLAUDE.md`, find:

```markdown
### Key design decisions
- `AuthService` and `ApiClient` are manual singletons (no DI framework) for simplicity
- `register` returns `201` with no token → app calls `login` immediately after to get the JWT
- `FutureBuilder` pattern used throughout — no Riverpod/BLoC overhead
- `withValues(alpha:)` used instead of deprecated `withOpacity` in Flutter 3.19+

---

## Running locally (without Docker)
```

Replace with:

```markdown
### Key design decisions
- `AuthService` and `ApiClient` are manual singletons (no DI framework) for simplicity
- `register` returns `201` with no token → app calls `login` immediately after to get the JWT
- `FutureBuilder` pattern used throughout — no Riverpod/BLoC overhead
- `withValues(alpha:)` used instead of deprecated `withOpacity` in Flutter 3.19+

### Apple Watch companion app — offline support

The Watch app (`mobile/ios/Watch App Watch App/`, SwiftUI, see `docs/superpowers/specs/2026-09-03-watch-app-design.md` for its original architecture) caches its last-successful `Public`/`Mine`/`Favourites` fetches to disk (`ComboCacheStore`, a single JSON file in Application Support) and falls back to that cache when a live fetch fails with a network-level error — "All" and "Landed" stay derived client-side from Public+Mine, same as when online. Favourite/landed toggles made while offline apply optimistically to the cache and enqueue a `PendingAction` (`OfflineSyncQueue`, its own JSON file) instead of failing silently; the queue is drained opportunistically — `APIClient`'s success path fires a fire-and-forget flush after every successful call, so no background monitoring or manual "sync" action is needed. `ComboRepository` (`mobile/ios/Watch App Watch App/Offline/`) is the single seam `FilterMenuView`/`ComboListView` go through for all of this instead of calling `APIClient` directly. A `401` never falls back to cache (an invalid/rotated token can mean the account changed) and a queue flush stops immediately on `401`, marking the existing reconnect state. Logging into a different account on the paired iPhone clears the cache and queue (`WatchAuthStore.apply(context:)`, compares the incoming `userName` against the previously-stored one). The Watch App target uses Xcode's `PBXFileSystemSynchronizedRootGroup` — any `.swift` file placed under `mobile/ios/Watch App Watch App/` is automatically included in the build, no `project.pbxproj` editing needed (unlike the Runner/iOS target elsewhere in this project). See `docs/superpowers/specs/2026-09-08-watch-offline-support-design.md` for the full design.

---

## Running locally (without Docker)
```

- [ ] **Step 2: Commit the docs change**

```bash
git add CLAUDE.md
git commit -m "Document Apple Watch offline support in CLAUDE.md"
```

- [ ] **Step 3: Final full build verification**

Run:
```bash
cd mobile && xcodebuild -workspace ios/Runner.xcworkspace -scheme "Watch App Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" -configuration Debug build
```
Expected: `** BUILD SUCCEEDED **`.

Also verify the main Runner (iOS) app + embedded Watch app still build together (confirms nothing here broke the existing iOS target that embeds this Watch app):

```bash
cd mobile && flutter build ios --no-codesign --simulator -d <a booted iOS simulator's device id, from `flutter devices`>
```
Expected: `✓ Built build/ios/iphonesimulator/Runner.app`.

- [ ] **Step 4: Manual verification (cannot be automated)**

Document as outstanding in the PR/handoff notes — this needs a paired Watch Simulator (or physical device) with a logged-in account:

1. Launch the Watch app, browse a couple of filters normally (confirms nothing regressed).
2. In the Simulator's `Features → Network Link Conditioner` (or by disabling the Mac's network entirely), simulate no connectivity.
3. Re-open a previously-viewed filter — confirm it shows the cached list with the "Offline · showing saved data" row, not an error.
4. Swipe to favourite/unfavourite and mark-landed/unmark on a couple of rows while offline — confirm the row updates immediately and the filter menu shows the "N changes will sync automatically" banner.
5. Restore connectivity, reopen the filter menu — confirm the banner disappears and the change is reflected on the phone/web without any manual action.
6. Log into a different account on the paired iPhone (or log out/back in as a different test user) — confirm the Watch's cached combos from the previous account are gone.
