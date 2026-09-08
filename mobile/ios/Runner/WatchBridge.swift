import Flutter
import WatchConnectivity

final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.rafaelffs.freestyleCombo/watch",
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "pushCredentials":
                guard
                    let args = call.arguments as? [String: Any],
                    let jwt = args["jwt"] as? String
                else {
                    result(FlutterError(code: "bad_args", message: "jwt required", details: nil))
                    return
                }
                var context: [String: Any] = ["jwt": jwt]
                if let userName = args["userName"] as? String {
                    context["userName"] = userName
                }
                self.push(context: context)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func push(context: [String: Any]) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext(context)
    }

    // No-ops required by the protocol — the phone side doesn't need to react
    // to anything the Watch sends back for this feature.
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
