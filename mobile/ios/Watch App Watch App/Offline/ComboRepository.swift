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
/// ComboCacheStore/OfflineSyncQueue are actors, so every call into them
/// below is awaited.
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
            await ComboCacheStore.shared.writePublic(combos)
            return ComboListResult(combos: combos, isFromCache: false)
        } catch let error as URLError {
            let cached = await ComboCacheStore.shared.read()
            if cached.publicUpdatedAt != nil {
                return ComboListResult(combos: cached.publicCombos, isFromCache: true)
            }
            throw error
        }
    }

    func loadMine() async throws -> ComboListResult {
        do {
            let combos = try await APIClient.shared.getMyCombos()
            await ComboCacheStore.shared.writeMine(combos)
            return ComboListResult(combos: combos, isFromCache: false)
        } catch let error as URLError {
            let cached = await ComboCacheStore.shared.read()
            if cached.mineUpdatedAt != nil {
                return ComboListResult(combos: cached.mineCombos, isFromCache: true)
            }
            throw error
        }
    }

    func loadFavourites() async throws -> ComboListResult {
        do {
            let combos = try await APIClient.shared.getFavourites()
            await ComboCacheStore.shared.writeFavourites(combos)
            return ComboListResult(combos: combos, isFromCache: false)
        } catch let error as URLError {
            let cached = await ComboCacheStore.shared.read()
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
    /// the other call). Otherwise, throws if EITHER sub-load throws — a
    /// partial "All" list silently missing every Public or every Mine combo
    /// would be more misleading than an error, so this never merges a
    /// half-populated result. isFromCache is true if either sub-load came
    /// from cache.
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

        guard let pub, let mine else {
            throw pubError ?? mineError ?? APIError.server("No data available")
        }

        var merged: [String: Combo] = [:]
        for c in mine.combos { merged[c.id] = c }
        for c in pub.combos where merged[c.id] == nil { merged[c.id] = c }

        let isFromCache = pub.isFromCache || mine.isFromCache
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
        await ComboCacheStore.shared.applyFavouriteToggle(comboId: combo.id, combo: updated)

        do {
            if newValue {
                try await APIClient.shared.addFavourite(id: combo.id)
            } else {
                try await APIClient.shared.removeFavourite(id: combo.id)
            }
            return updated
        } catch is URLError {
            await OfflineSyncQueue.shared.enqueue(comboId: combo.id, kind: newValue ? .favourite : .unfavourite)
            return updated
        } catch {
            await ComboCacheStore.shared.applyFavouriteToggle(comboId: combo.id, combo: combo)
            return combo
        }
    }

    func toggleDone(_ combo: Combo) async -> Combo {
        let newValue = !combo.isCompleted
        var updated = combo
        updated.isCompleted = newValue
        await ComboCacheStore.shared.applyDoneToggle(comboId: combo.id, isCompleted: newValue)

        do {
            if newValue {
                try await APIClient.shared.markCompleted(id: combo.id)
            } else {
                try await APIClient.shared.unmarkCompleted(id: combo.id)
            }
            return updated
        } catch is URLError {
            await OfflineSyncQueue.shared.enqueue(comboId: combo.id, kind: newValue ? .complete : .uncomplete)
            return updated
        } catch {
            await ComboCacheStore.shared.applyDoneToggle(comboId: combo.id, isCompleted: combo.isCompleted)
            return combo
        }
    }
}
