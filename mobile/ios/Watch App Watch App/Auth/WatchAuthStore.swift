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
            KeychainStore.set(jwt, forKey: jwtKey)
            self.token = jwt
            self.needsReconnect = false
            if let name = context["userName"] as? String {
                KeychainStore.set(name, forKey: userNameKey)
                self.userName = name
            }
        }
    }

    func markReconnectNeeded() {
        DispatchQueue.main.async {
            self.needsReconnect = true
        }
    }
}
