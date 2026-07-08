import 'dart:convert';

/// The pairing artifact a guest scans to both join the hotspot and locate the
/// host. See specs/001-direct-transfer/contracts/qr-pairing.md.
///
/// Primary form:  `lsd://v1/<base64url(json)>` — carries everything a guest
/// needs (credentials + host IP/port/protocol + session token).
/// Fallback form: `WIFI:T:WPA;S:<ssid>;P:<pass>;;` — a stock camera app can at
/// least join the network from this.
class PairingPayload {
  final int version;
  final String ssid;
  final String password;
  final String? host;
  final int? port;
  final String protocol; // 'http' | 'https'
  final String? fingerprint;
  final String? sessionToken;

  const PairingPayload({
    this.version = 1,
    required this.ssid,
    required this.password,
    this.host,
    this.port,
    this.protocol = 'http',
    this.fingerprint,
    this.sessionToken,
  });

  /// `true` when the payload carries enough to connect directly (not just join).
  bool get canConnectDirectly => host != null && port != null;

  /// The host transfer/web base URL, when host+port are known.
  String? get baseUrl => canConnectDirectly ? '$protocol://$host:$port' : null;

  /// Primary QR string: `lsd://v<version>/<base64url(json)>`.
  String toUri() {
    final map = <String, dynamic>{
      'v': version,
      'ssid': ssid,
      'password': password,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      'protocol': protocol,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (sessionToken != null) 'sessionToken': sessionToken,
    };
    final encoded = base64Url.encode(utf8.encode(jsonEncode(map)));
    return 'lsd://v$version/$encoded';
  }

  /// Standard WiFi QR fallback (join-only).
  String toWifiQr() {
    String esc(String v) => v
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(':', r'\:')
        .replaceAll(',', r'\,');
    return 'WIFI:T:WPA;S:${esc(ssid)};P:${esc(password)};;';
  }

  /// Parses either an `lsd://` payload (full) or a `WIFI:` string (join-only).
  /// Returns null for anything it does not understand.
  static PairingPayload? tryParse(String raw) {
    final input = raw.trim();
    if (input.startsWith('lsd://')) return _parseLsd(input);
    if (input.startsWith('WIFI:')) return _parseWifi(input);
    return null;
  }

  static PairingPayload? _parseLsd(String input) {
    try {
      final afterScheme = input.substring('lsd://'.length); // v1/<b64>
      final slash = afterScheme.indexOf('/');
      if (slash < 0) return null;
      final encoded = afterScheme.substring(slash + 1);
      final json = utf8.decode(base64Url.decode(encoded));
      final map = jsonDecode(json) as Map<String, dynamic>;
      return PairingPayload(
        version: (map['v'] as num?)?.toInt() ?? 1,
        ssid: map['ssid'] as String,
        password: map['password'] as String,
        host: map['host'] as String?,
        port: (map['port'] as num?)?.toInt(),
        protocol: (map['protocol'] as String?) ?? 'http',
        fingerprint: map['fingerprint'] as String?,
        sessionToken: map['sessionToken'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static PairingPayload? _parseWifi(String input) {
    String unesc(String v) => v
        .replaceAll(r'\;', ';')
        .replaceAll(r'\:', ':')
        .replaceAll(r'\,', ',')
        .replaceAll(r'\\', r'\');
    final ssid = RegExp(r'S:((?:\\.|[^;])+)').firstMatch(input)?.group(1);
    final pass = RegExp(r'P:((?:\\.|[^;])+)').firstMatch(input)?.group(1);
    if (ssid == null || pass == null) return null;
    return PairingPayload(ssid: unesc(ssid), password: unesc(pass));
  }
}
