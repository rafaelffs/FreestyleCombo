// mobile/ios/Watch App/Screens/ComboListView.swift
import SwiftUI

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

    private var emptyTitle: String {
        switch filter {
        case .favourites: return "No favourites yet"
        case .done: return "Nothing landed yet"
        case .mine: return "You haven't built any combos yet"
        default: return "No combos"
        }
    }

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
    /// On the Favourites screen, an unfavourite also removes the row; on the
    /// Landed screen, un-marking a combo as done does the same — each
    /// matches what a live re-fetch of that filter's own endpoint would
    /// return.
    private func applyLocalUpdate(_ updated: Combo) {
        if filter == .favourites && !updated.isFavourited {
            combos.removeAll { $0.id == updated.id }
        } else if filter == .done && !updated.isCompleted {
            combos.removeAll { $0.id == updated.id }
        } else if let index = combos.firstIndex(where: { $0.id == updated.id }) {
            combos[index] = updated
        }
    }
}

private struct ComboRow: View {
    let combo: Combo

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(combo.displayName)
                .font(.system(.body, design: .monospaced))
                .lineLimit(2)
            HStack(spacing: 6) {
                Text("\(Int(combo.totalDifficulty))")
                    .font(.caption2.bold())
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Color.indigo, in: Capsule())
                    .foregroundStyle(.white)
                if let owner = combo.ownerUserName {
                    Text("by \(owner)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

extension Combo: Hashable {
    static func == (lhs: Combo, rhs: Combo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
