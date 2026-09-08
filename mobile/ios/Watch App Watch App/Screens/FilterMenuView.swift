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
}

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
