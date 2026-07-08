import 'package:localsend_app/provider/direct/direct_pairing.dart';

/// Lifecycle of a hosting session (data-model.md).
enum DirectSessionState { starting, waiting, active, ending, ended, error }

/// How a participant is connected to the host.
enum ParticipantPlatform { phoneApp, browser, desktopApp }

enum ParticipantConnectionState { connected, transferring, disconnected }

/// A device connected to a [DirectSession].
class Participant {
  final String id;
  final String displayName;
  final ParticipantPlatform platform;
  final String ip;
  final ParticipantConnectionState connectionState;
  final double? progress;

  const Participant({
    required this.id,
    required this.displayName,
    required this.platform,
    required this.ip,
    this.connectionState = ParticipantConnectionState.connected,
    this.progress,
  });

  Participant copyWith({
    String? displayName,
    ParticipantPlatform? platform,
    String? ip,
    ParticipantConnectionState? connectionState,
    double? progress,
  }) {
    return Participant(
      id: id,
      displayName: displayName ?? this.displayName,
      platform: platform ?? this.platform,
      ip: ip ?? this.ip,
      connectionState: connectionState ?? this.connectionState,
      progress: progress ?? this.progress,
    );
  }
}

/// An active hosting session, from hotspot-up to teardown.
class DirectSession {
  final String id;
  final String ssid;
  final String password;
  final String? hostIp;
  final int port;
  final String protocol; // 'http' | 'https'
  final String sessionToken;
  final List<Participant> participants;
  final DirectSessionState state;
  final DateTime startedAt;
  final String? errorMessage;

  const DirectSession({
    required this.id,
    required this.ssid,
    required this.password,
    required this.hostIp,
    required this.port,
    required this.protocol,
    required this.sessionToken,
    required this.participants,
    required this.state,
    required this.startedAt,
    this.errorMessage,
  });

  /// Browser guests open this address; null until the host IP is known.
  String? get webUrl => hostIp == null ? null : '$protocol://$hostIp:$port';

  /// The pairing payload encoded into the QR shown to guests.
  PairingPayload get pairingPayload => PairingPayload(
        ssid: ssid,
        password: password,
        host: hostIp,
        port: port,
        protocol: protocol,
        sessionToken: sessionToken,
      );

  DirectSession copyWith({
    String? hostIp,
    List<Participant>? participants,
    DirectSessionState? state,
    String? errorMessage,
  }) {
    return DirectSession(
      id: id,
      ssid: ssid,
      password: password,
      hostIp: hostIp ?? this.hostIp,
      port: port,
      protocol: protocol,
      sessionToken: sessionToken,
      participants: participants ?? this.participants,
      state: state ?? this.state,
      startedAt: startedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
