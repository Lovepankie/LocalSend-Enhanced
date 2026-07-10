import 'package:flutter/services.dart';
import 'package:localsend_app/service/wifi_direct_service.dart';

/// Android implementation using WifiManager.startLocalOnlyHotspot() (API 26+)
/// via a MethodChannel backed by Kotlin code in android/app/.../WifiDirectPlugin.kt
class AndroidWifiDirectService implements WifiDirectService {
  static const _channel = MethodChannel('localsend/wifi_direct');

  @override
  bool get canHost => true;

  @override
  bool get canJoin => true;

  @override
  Future<HotspotCredentials> startHotspot() async {
    try {
      final result = await _channel.invokeMapMethod<String, String>(
        'startHotspot',
      );
      if (result == null) {
        throw const WifiDirectException(
          'No hotspot credentials returned from platform',
        );
      }
      return HotspotCredentials(
        ssid: result['ssid']!,
        passphrase: result['passphrase']!,
        bssid: result['bssid'],
        hostIp: result['host'],
      );
    } on PlatformException catch (e) {
      throw WifiDirectException('Failed to start hotspot: ${e.message}');
    }
  }

  @override
  Future<void> stopHotspot() async {
    try {
      await _channel.invokeMethod<void>('stopHotspot');
    } on PlatformException catch (e) {
      throw WifiDirectException('Failed to stop hotspot: ${e.message}');
    }
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
