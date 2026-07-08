import 'package:localsend_app/provider/direct/direct_pairing.dart';
import 'package:localsend_app/provider/settings_provider.dart';
import 'package:localsend_app/service/wifi_direct_service.dart';
import 'package:localsend_app/service/wifi_direct_service_factory.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:uuid/uuid.dart';

enum WifiDirectMode { idle, hosting, joining, connected }

class WifiDirectState {
  final WifiDirectMode mode;
  final HotspotCredentials? credentials;

  /// The full pairing payload (credentials + host IP/port/token) shown as the
  /// primary `lsd://` QR when hosting. Null until the hotspot is up.
  final PairingPayload? pairing;

  final String? errorMessage;

  const WifiDirectState({
    required this.mode,
    this.credentials,
    this.pairing,
    this.errorMessage,
  });

  WifiDirectState copyWith({
    WifiDirectMode? mode,
    HotspotCredentials? credentials,
    PairingPayload? pairing,
    String? errorMessage,
  }) {
    return WifiDirectState(
      mode: mode ?? this.mode,
      credentials: credentials ?? this.credentials,
      pairing: pairing ?? this.pairing,
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
  final _uuid = const Uuid();

  @override
  WifiDirectState init() {
    _service = createWifiDirectService();
    return WifiDirectState.idle;
  }

  bool get canHost => _service.canHost;
  bool get canJoin => _service.canJoin;

  /// Creates a local WiFi hotspot and builds the pairing payload for QR display.
  Future<void> startHotspot() async {
    state = state.copyWith(mode: WifiDirectMode.hosting, errorMessage: null);
    try {
      final credentials = await _service.startHotspot();
      final settings = ref.read(settingsProvider);
      final pairing = PairingPayload(
        ssid: credentials.ssid,
        password: credentials.passphrase,
        host: credentials.hostIp,
        port: settings.port,
        protocol: settings.https ? 'https' : 'http',
        sessionToken: _uuid.v4(),
      );
      state = state.copyWith(credentials: credentials, pairing: pairing);
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

  /// Joins a hotspot described by a scanned pairing payload.
  Future<void> joinFromPairing(PairingPayload pairing) async {
    await joinHotspot(
      HotspotCredentials(
        ssid: pairing.ssid,
        passphrase: pairing.password,
        hostIp: pairing.host,
      ),
    );
  }

  /// Joins a hotspot from credentials (scanned or entered manually).
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
