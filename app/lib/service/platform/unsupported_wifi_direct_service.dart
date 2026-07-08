import 'package:localsend_app/service/wifi_direct_service.dart';

/// Fallback for platforms that have no WiFi Direct support at all.
class UnsupportedWifiDirectService implements WifiDirectService {
  @override
  bool get canHost => false;

  @override
  bool get canJoin => false;

  @override
  Future<HotspotCredentials> startHotspot() async {
    throw const WifiDirectException(
      'WiFi Direct is not supported on this platform.',
    );
  }

  @override
  Future<void> stopHotspot() async {}

  @override
  Future<void> joinHotspot(HotspotCredentials credentials) async {
    throw const WifiDirectException(
      'WiFi Direct is not supported on this platform.',
    );
  }

  @override
  Future<void> leaveHotspot() async {}
}
