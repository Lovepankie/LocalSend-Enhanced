/// Abstract WiFi Direct / SoftAP service.
///
/// Platform implementations:
/// - Android: WifiManager.startLocalOnlyHotspot() + WifiNetworkSuggestion
/// - iOS:     NEHotspotConfiguration (join only; hosting requires user action)
/// - Desktop: nmcli (Linux) / netsh (Windows) via shell commands
///
/// The QR payload uses the standard WiFi QR format:
///   WIFI:T:WPA;S:<ssid>;P:<passphrase>;;
abstract class WifiDirectService {
  /// Starts a local-only WiFi hotspot.
  /// Returns [HotspotCredentials] on success.
  /// Throws [WifiDirectException] on failure.
  Future<HotspotCredentials> startHotspot();

  /// Stops the local-only hotspot started by [startHotspot].
  Future<void> stopHotspot();

  /// Connects this device to a hotspot described by [credentials].
  /// After this resolves, the device is on the P2P subnet and
  /// LocalSend's existing discovery can run normally.
  Future<void> joinHotspot(HotspotCredentials credentials);

  /// Disconnects from the hotspot joined via [joinHotspot].
  Future<void> leaveHotspot();

  /// Returns true if this platform supports programmatic hotspot creation.
  bool get canHost;

  /// Returns true if this platform supports programmatic hotspot joining.
  bool get canJoin;
}

class HotspotCredentials {
  final String ssid;
  final String passphrase;
  final String? bssid;

  const HotspotCredentials({
    required this.ssid,
    required this.passphrase,
    this.bssid,
  });

  /// Encodes as the standard WiFi QR format.
  /// Any camera app (Android, iOS) can scan this and connect automatically.
  String toQrPayload() {
    final escapedSsid = ssid.replaceAll('"', '\\"');
    final escapedPass = passphrase.replaceAll('"', '\\"');
    return 'WIFI:T:WPA;S:$escapedSsid;P:$escapedPass;;';
  }

  static HotspotCredentials? fromQrPayload(String payload) {
    if (!payload.startsWith('WIFI:')) return null;
    final ssidMatch = RegExp(r'S:([^;]+)').firstMatch(payload);
    final passMatch = RegExp(r'P:([^;]+)').firstMatch(payload);
    if (ssidMatch == null || passMatch == null) return null;
    return HotspotCredentials(
      ssid: ssidMatch.group(1)!,
      passphrase: passMatch.group(1)!,
    );
  }
}

class WifiDirectException implements Exception {
  final String message;
  const WifiDirectException(this.message);

  @override
  String toString() => 'WifiDirectException: $message';
}
