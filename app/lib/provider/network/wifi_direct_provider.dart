import 'package:localsend_app/service/wifi_direct_service.dart';
import 'package:localsend_app/service/wifi_direct_service_factory.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum WifiDirectMode { idle, hosting, joining, connected }

class WifiDirectState {
  final WifiDirectMode mode;
  final HotspotCredentials? credentials;
  final String? errorMessage;

  const WifiDirectState({
    required this.mode,
    this.credentials,
    this.errorMessage,
  });

  WifiDirectState copyWith({
    WifiDirectMode? mode,
    HotspotCredentials? credentials,
    String? errorMessage,
  }) {
    return WifiDirectState(
      mode: mode ?? this.mode,
      credentials: credentials ?? this.credentials,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static const idle = WifiDirectState(mode: WifiDirectMode.idle);
}

final wifiDirectProvider =
    NotifierProvider<WifiDirectNotifier, WifiDirectState>((ref) {
      return WifiDirectNotifier();
    });

class WifiDirectNotifier extends Notifier<WifiDirectState> {
  late final WifiDirectService _service;

  @override
  WifiDirectState init() {
    _service = createWifiDirectService();
    return WifiDirectState.idle;
  }

  bool get canHost => _service.canHost;
  bool get canJoin => _service.canJoin;

  /// Creates a local WiFi hotspot and stores the credentials for QR display.
  Future<void> startHotspot() async {
    state = state.copyWith(mode: WifiDirectMode.hosting, errorMessage: null);
    try {
      final credentials = await _service.startHotspot();
      state = state.copyWith(credentials: credentials);
    } catch (e) {
      state = WifiDirectState(
        mode: WifiDirectMode.idle,
        errorMessage: e.toString(),
      );
    }
  }

  /// Stops the hosted hotspot and resets state.
  Future<void> stopHotspot() async {
    try {
      await _service.stopHotspot();
    } catch (_) {}
    state = WifiDirectState.idle;
  }

  /// Joins a hotspot from scanned QR credentials.
  Future<void> joinHotspot(HotspotCredentials credentials) async {
    state = WifiDirectState(
      mode: WifiDirectMode.joining,
      credentials: credentials,
    );
    try {
      await _service.joinHotspot(credentials);
      state = state.copyWith(mode: WifiDirectMode.connected);
    } catch (e) {
      state = WifiDirectState(
        mode: WifiDirectMode.idle,
        errorMessage: e.toString(),
      );
    }
  }

  /// Leaves the currently joined hotspot.
  Future<void> leaveHotspot() async {
    try {
      await _service.leaveHotspot();
    } catch (_) {}
    state = WifiDirectState.idle;
  }
}
