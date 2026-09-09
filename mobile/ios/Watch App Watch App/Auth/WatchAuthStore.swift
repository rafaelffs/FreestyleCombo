import Combine
import Foundation
import WatchConnectivity

private let jwtKey = "fc_jwt"
private let userNameKey = "fc_user_name"

final class WatchAuthStore: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchAuthStore()

    @Published private(set) var token: String?
    @Published private(set) var userName: String?
    /// Set to true on a 401 from any API call — drives the "open your
    /// iPhone" reconnect empty state described in the design doc.
    @Published var needsReconnect = false

    private override init() {
        super.init()
        token = KeychainStore.get(jwtKey)
        userName = KeychainStore.get(userNameKey)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        // No action needed on activation completing — didReceiveApplicationContext
        // fires independently once the iPhone has pushed a context at least once.
        // If the session already has a context waiting (delivered while the Watch
        // app wasn't running), apply it now instead of waiting for a fresh push.
        if !session.receivedApplicationContext.isEmpty {
            apply(context: session.receivedApplicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(context: applicationContext)
    }

    private func apply(context: [String: Any]) {
        DispatchQueue.main.async {
            guard let jwt = context["jwt"] as? String, !jwt.isEmpty else { return }
            let newName = context["userName"] as? String

            func applyCredentials() {
                KeychainStore.set(jwt, forKey: jwtKey)
                self.token = jwt
                self.needsReconnect = false
                if let newName {
                    KeychainStore.set(newName, forKey: userNameKey)
                    self.userName = newName
                }
            }

            // A different account logged in on the paired iPhone — drop this
            // account's cached combos and queued offline toggles, and only
            // THEN apply the new credentials. Setting self.token is what lets
            // ComboListView leave the reconnect screen and start making live
            // API calls — if that happened before the clear finished, a
            // queued old-account toggle could get replayed under the new
            // account's token via APIClient's opportunistic flush trigger, a
            // real cross-account data bug, not just a UI staleness flash.
            // ComboCacheStore/OfflineSyncQueue are actors, so their calls
            // need `await` — wrapped in a Task since this closure itself is
            // synchronous, hopping back via MainActor.run to safely touch
            // @Published state afterward.
            if let newName, let previousName = self.userName, newName != previousName {
                Task {
                    await ComboCacheStore.shared.clear()
                    await OfflineSyncQueue.shared.clear()
                    await MainActor.run { applyCredentials() }
                }
            } else {
                applyCredentials()
            }
        }
    }

    func markReconnectNeeded() {
        DispatchQueue.main.async {
            self.needsReconnect = true
        }
    }
}
