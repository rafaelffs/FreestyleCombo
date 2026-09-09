// mobile/ios/Watch App/Offline/OfflineSyncQueue.swift
import Foundation
import os

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
/// An actor: ComboRepository's toggleFavourite/toggleDone can both enqueue
/// around the same time as APIClient's success-triggered flush is already
/// draining the queue — actor isolation serializes access to `pending`
/// instead of racing on a plain mutable array.
actor OfflineSyncQueue {
    static let shared = OfflineSyncQueue()

    private(set) var pending: [PendingAction]
    private var isFlushing = false
    private let fileURL: URL
    private let logger = Logger(subsystem: "com.rafaelffs.freestyleCombo.watchkitapp", category: "OfflineSyncQueue")

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
    /// recursive invocation via isFlushing — a successful replay call goes
    /// through APIClient, whose own success path also calls this method
    /// (see APIClient.triggerSyncFlush), so without the guard this would
    /// recurse into itself. Removes each action by id rather than
    /// pending.removeFirst() — `replay(action)`'s await can suspend for a
    /// while, during which `enqueue()` (also actor-isolated, so it can only
    /// run in a gap between this method's own suspension points, but that
    /// gap exists right here) could have removed or reordered the front of
    /// the queue; removing by id guarantees the action actually just
    /// processed is the one that gets removed, not whatever now happens to
    /// sit at index 0.
    func flushIfNeeded() async {
        guard !isFlushing, !pending.isEmpty else { return }
        isFlushing = true
        defer { isFlushing = false }

        while let action = pending.first {
            do {
                try await replay(action)
                pending.removeAll { $0.id == action.id }
                persist()
            } catch APIError.unauthorized {
                await MainActor.run { WatchAuthStore.shared.markReconnectNeeded() }
                return
            } catch is URLError {
                // Network still down — stop, leave this and the rest queued for next time.
                return
            } catch {
                // Definitive rejection (e.g. combo deleted) — drop just this one, keep going.
                pending.removeAll { $0.id == action.id }
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
        guard let data = try? JSONEncoder().encode(pending) else {
            logger.error("Failed to encode pending actions")
            return
        }
        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to write pending_actions.json: \(error, privacy: .public)")
        }
    }
}
