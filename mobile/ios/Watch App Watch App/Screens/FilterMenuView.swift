// mobile/ios/Watch App/Screens/FilterMenuView.swift
import SwiftUI

enum ComboFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case pub = "Public"
    case mine = "Mine"
    case favourites = "Favourites"
    case done = "Landed"

    var id: String { rawValue }

    var dotColor: Color {
        switch self {
        case .all: return .indigo
        case .pub: return .purple
        case .mine: return .white
        case .favourites: return .pink
        case .done: return .green
        }
    }

    func fetch() async throws -> ComboListResult {
        switch self {
        case .all: return try await ComboRepository.shared.loadAll()
        case .pub: return try await ComboRepository.shared.loadPublic()
        case .mine: return try await ComboRepository.shared.loadMine()
        case .favourites: return try await ComboRepository.shared.loadFavourites()
        case .done: return try await ComboRepository.shared.loadDone()
        }
    }
}

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

    private func loadCounts() async {
        // Computed unconditionally, before the guard below — the pending
        // count has nothing to do with whether the three list fetches
        // succeed, so a failure in any of them shouldn't also suppress the
        // "N changes will sync automatically" banner.
        pendingCount = await OfflineSyncQueue.shared.count

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
    }
}

private struct ReconnectView: View {
    var body: some View {
        ContentUnavailableView(
            "Reconnect needed",
            systemImage: "iphone.and.arrow.forward",
            description: Text("Open FreestyleCombo on your iPhone to reconnect.")
        )
    }
}
