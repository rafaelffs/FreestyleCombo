// mobile/ios/Watch App/Networking/APIClient.swift
import Foundation

enum APIError: Error {
    case unauthorized
    case server(String)
    case decoding
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Reconnect needed."
        case .server(let message): return message
        case .decoding: return "Couldn't read the server's response."
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    // Matches mobile/lib/core/api/api_client.dart's kBaseUrl split.
    #if DEBUG
    private let baseURL = URL(string: "http://localhost:5050/api")!
    #else
    private let baseURL = URL(string: "https://www.fscombo.com/api")!
    #endif

    private let decoder = JSONDecoder()

    private struct ErrorPayload: Decodable { let error: String }

    private func errorMessage(from data: Data, statusCode: Int) -> String {
        if let payload = try? JSONDecoder().decode(ErrorPayload.self, from: data) {
            return payload.error
        }
        return "HTTP \(statusCode)"
    }

    private func request(_ path: String, query: [String: String] = [:]) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        if let token = WatchAuthStore.shared.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

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

    func getPublicCombos() async throws -> [Combo] {
        let req = try request("/combos/public", query: ["page": "1", "pageSize": "50"])
        return try await send(req, as: PagedResult<Combo>.self).items
    }

    func getMyCombos() async throws -> [Combo] {
        let req = try request("/combos/mine", query: ["page": "1", "pageSize": "50"])
        return try await send(req, as: PagedResult<Combo>.self).items
    }

    func getFavourites() async throws -> [Combo] {
        let req = try request("/combos/favourites")
        return try await send(req, as: [Combo].self)
    }

    private func mutate(_ path: String, method: String) async throws {
        var req = try request(path)
        req.httpMethod = method
        try await sendNoBody(req)
    }

    func addFavourite(id: String) async throws { try await mutate("/combos/\(id)/favourite", method: "POST") }
    func removeFavourite(id: String) async throws { try await mutate("/combos/\(id)/favourite", method: "DELETE") }
    func markCompleted(id: String) async throws { try await mutate("/combos/\(id)/complete", method: "POST") }
    func unmarkCompleted(id: String) async throws { try await mutate("/combos/\(id)/complete", method: "DELETE") }
}
