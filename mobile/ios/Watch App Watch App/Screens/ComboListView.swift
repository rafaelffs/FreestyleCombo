// mobile/ios/Watch App/Screens/ComboListView.swift
import SwiftUI

struct ComboListView: View {
    let filter: ComboFilter

    @State private var combos: [Combo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let errorMessage {
                ContentUnavailableView(
                    "Couldn't load combos",
                    systemImage: "wifi.slash",
                    description: Text(errorMessage)
                )
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
                        Button {
                            Task { await toggleDone(combo) }
                        } label: {
                            Label("Done", systemImage: combo.isCompleted ? "xmark.circle" : "checkmark.circle")
                        }
                        .tint(.green)
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
        case .done: return "Nothing marked done yet"
        case .mine: return "You haven't built any combos yet"
        default: return "No combos"
        }
    }

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

    private func toggleFavourite(_ combo: Combo) async {
        do {
            if combo.isFavourited {
                try await APIClient.shared.removeFavourite(id: combo.id)
            } else {
                try await APIClient.shared.addFavourite(id: combo.id)
            }
            await load() // refetch rather than mutate local state — see design doc
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
            await load()
        } catch {
            // Same rationale as toggleFavourite.
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
