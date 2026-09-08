// mobile/ios/Watch App/Offline/ComboCacheStore.swift
import Foundation
import os

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
    private let logger = Logger(subsystem: "com.rafaelffs.freestyleCombo.watchkitapp", category: "ComboCacheStore")

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
    /// match what GET /combos/favourites would return. `combo.isFavourited`
    /// is the single source of truth for the new state — the caller must pass
    /// a combo that already carries it.
    func applyFavouriteToggle(comboId: String, combo: Combo) {
        cache.publicCombos = cache.publicCombos.map { c in
            var c = c
            if c.id == comboId { c.isFavourited = combo.isFavourited }
            return c
        }
        cache.mineCombos = cache.mineCombos.map { c in
            var c = c
            if c.id == comboId { c.isFavourited = combo.isFavourited }
            return c
        }
        if combo.isFavourited {
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
        guard let data = try? JSONEncoder().encode(cache) else {
            logger.error("Failed to encode ComboCache")
            return
        }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to write combo_cache.json: \(error, privacy: .public)")
        }
    }
}
