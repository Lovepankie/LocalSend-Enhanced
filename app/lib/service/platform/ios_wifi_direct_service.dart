import 'package:flutter/services.dart';
import 'package:localsend_app/service/wifi_direct_service.dart';

/// iOS implementation.
/// Hosting: iOS does not allow programmatic hotspot creation — canHost is false.
///          The UI guides users to enable Personal Hotspot manually.
/// Joining: Uses NEHotspotConfiguration via Swift MethodChannel.
class IosWifiDirectService implements WifiDirectService {
  static const _channel = MethodChannel('localsend/wifi_direct');

  @override
  bool get canHost => false; // iOS sandbox restriction

  @override
  bool get canJoin => true;

  @override
  Future<HotspotCredentials> startHotspot() async {
    // iOS cannot create hotspots programmatically.
    // The UI should detect canHost == false and show manual instructions instead.
    throw const WifiDirectException(
      'iOS cannot create a hotspot programmatically. '
      'Please enable Personal Hotspot in Settings.',
    );
  }

  @override
  Future<void> stopHotspot() async {
    // No-op: user controls hotspot lifecycle on iOS.
  }

  @override
  Future<void> joinHotspot(HotspotCredentials credentials) async {
    try {
      await _channel.invokeMethod<void>('joinHotspot', {
        'ssid': credentials.ssid,
        'passphrase': credentials.passphrase,
      });
    } on PlatformException catch (e) {
      throw WifiDirectException('Failed to join hotspot: ${e.message}');
    }
  }

  @override
  Future<void> leaveHotspot() async {
    try {
      await _channel.invokeMethod<void>('leaveHotspot');
    } on PlatformException catch (e) {
      throw WifiDirectException('Failed to leave hotspot: ${e.message}');
    }
  }
}
