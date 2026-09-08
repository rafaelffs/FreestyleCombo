import Flutter
import UIKit

/// Hands a PNG image to Instagram's Story composer via the documented
/// sticker-share mechanism: place the image on the pasteboard under
/// Instagram's well-known key, then open the instagram-stories:// URL
/// scheme. Instagram reads the pasteboard item itself — there's no
/// response payload, just success/failure of opening the URL.
final class InstagramShareBridge: NSObject {
    static let shared = InstagramShareBridge()

    func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.rafaelffs.freestyleCombo/instagram_share",
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "shareToInstagramStory":
                guard
                    let args = call.arguments as? [String: Any],
                    let imageData = args["image"] as? FlutterStandardTypedData
                else {
                    result(FlutterError(code: "bad_args", message: "image required", details: nil))
                    return
                }
                self.share(pngData: imageData.data, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func share(pngData: Data, result: @escaping FlutterResult) {
        guard
            let bundleId = Bundle.main.bundleIdentifier,
            let urlScheme = URL(string: "instagram-stories://share?source_application=\(bundleId)"),
            UIApplication.shared.canOpenURL(urlScheme)
        else {
            result(FlutterError(code: "not_installed", message: "Instagram is not installed", details: nil))
            return
        }

        let pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.stickerImage": pngData
        ]
        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [
            .expirationDate: Date().addingTimeInterval(60 * 5)
        ]
        UIPasteboard.general.setItems([pasteboardItems], options: pasteboardOptions)

        UIApplication.shared.open(urlScheme, options: [:]) { success in
            if success {
                result(nil)
            } else {
                result(FlutterError(code: "open_failed", message: "Could not open Instagram", details: nil))
            }
        }
    }
}
