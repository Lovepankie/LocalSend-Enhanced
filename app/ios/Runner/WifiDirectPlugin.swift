import Flutter
import NetworkExtension

/// Handles WiFi Direct / Hotspot joining on iOS via NEHotspotConfiguration.
/// iOS cannot create hotspots programmatically — only joining is supported.
///
/// Requires the "Hotspot Configuration" entitlement (com.apple.developer.networking.HotspotConfiguration)
/// in Runner.entitlements and the NEHotspotConfiguration framework.
class WifiDirectPlugin: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "localsend/wifi_direct",
            binaryMessenger: registrar.messenger()
        )
        let instance = WifiDirectPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startHotspot":
            result(FlutterError(
                code: "UNSUPPORTED",
                message: "iOS cannot create a hotspot programmatically. Enable Personal Hotspot in Settings.",
                details: nil
            ))

        case "stopHotspot":
            result(nil)

        case "joinHotspot":
            guard let args = call.arguments as? [String: String],
                  let ssid = args["ssid"],
                  let passphrase = args["passphrase"] else {
                result(FlutterError(code: "INVALID_ARGS", message: "ssid and passphrase required", details: nil))
                return
            }
            joinHotspot(ssid: ssid, passphrase: passphrase, result: result)

        case "leaveHotspot":
            leaveHotspot(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func joinHotspot(ssid: String, passphrase: String, result: @escaping FlutterResult) {
        let config = NEHotspotConfiguration(ssid: ssid, passphrase: passphrase, isWEP: false)
        config.joinOnce = false

        NEHotspotConfigurationManager.shared.apply(config) { error in
            if let error = error {
                let nsError = error as NSError
                // Code 13 means already connected to this SSID — treat as success
                if nsError.domain == NEHotspotConfigurationErrorDomain && nsError.code == 13 {
                    result(nil)
                } else {
                    result(FlutterError(
                        code: "JOIN_FAILED",
                        message: error.localizedDescription,
                        details: nil
                    ))
                }
            } else {
                result(nil)
            }
        }
    }

    private func leaveHotspot(result: @escaping FlutterResult) {
        // iOS: removing the hotspot configuration disconnects from that network.
        // We remove all LocalSend-managed configs.
        NEHotspotConfigurationManager.shared.getConfiguredSSIDs { ssids in
            for ssid in ssids {
                NEHotspotConfigurationManager.shared.removeConfiguration(forSSID: ssid)
            }
            result(nil)
        }
    }
}
