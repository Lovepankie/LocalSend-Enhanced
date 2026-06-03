import 'dart:io';

import 'package:localsend_app/service/wifi_direct_service.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

final _logger = Logger('DesktopWifiDirect');
const _uuid = Uuid();

/// Desktop implementation.
/// Linux: uses nmcli to create/destroy a hotspot AP connection.
/// Windows: uses netsh wlan to create a hosted network.
/// macOS: limited support — guides user to use Internet Sharing manually.
class DesktopWifiDirectService implements WifiDirectService {
  String? _activeConnectionId;
  HotspotCredentials? _activeCredentials;

  @override
  bool get canHost => Platform.isLinux || Platform.isWindows;

  @override
  bool get canJoin => Platform.isLinux || Platform.isWindows;

  @override
  Future<HotspotCredentials> startHotspot() async {
    if (Platform.isLinux) return _startLinuxHotspot();
    if (Platform.isWindows) return _startWindowsHotspot();
    throw const WifiDirectException('Hotspot creation not supported on macOS.');
  }

  @override
  Future<void> stopHotspot() async {
    if (Platform.isLinux) await _stopLinuxHotspot();
    if (Platform.isWindows) await _stopWindowsHotspot();
  }

  @override
  Future<void> joinHotspot(HotspotCredentials credentials) async {
    if (Platform.isLinux) return _joinLinuxHotspot(credentials);
    if (Platform.isWindows) return _joinWindowsHotspot(credentials);
    throw const WifiDirectException('Joining hotspot not supported on macOS.');
  }

  @override
  Future<void> leaveHotspot() async {
    if (Platform.isLinux) await _leaveLinuxHotspot();
    if (Platform.isWindows) await _leaveWindowsHotspot();
  }

  // ── Linux (nmcli) ──────────────────────────────────────────────────────────

  Future<HotspotCredentials> _startLinuxHotspot() async {
    final ssid = 'LocalSend-${_uuid.v4().substring(0, 6).toUpperCase()}';
    final passphrase = _uuid.v4().replaceAll('-', '').substring(0, 12);
    final connId = 'localsend-hotspot';

    _logger.info('Creating Linux hotspot: $ssid');
    final result = await Process.run('nmcli', [
      'device', 'wifi', 'hotspot',
      'con-name', connId,
      'ssid', ssid,
      'password', passphrase,
    ]);

    if (result.exitCode != 0) {
      throw WifiDirectException('nmcli failed: ${result.stderr}');
    }

    _activeConnectionId = connId;
    _activeCredentials = HotspotCredentials(ssid: ssid, passphrase: passphrase);
    return _activeCredentials!;
  }

  Future<void> _stopLinuxHotspot() async {
    final id = _activeConnectionId;
    if (id == null) return;
    await Process.run('nmcli', ['connection', 'delete', id]);
    _activeConnectionId = null;
    _activeCredentials = null;
  }

  Future<void> _joinLinuxHotspot(HotspotCredentials credentials) async {
    final result = await Process.run('nmcli', [
      'device', 'wifi', 'connect', credentials.ssid,
      'password', credentials.passphrase,
    ]);
    if (result.exitCode != 0) {
      throw WifiDirectException('nmcli connect failed: ${result.stderr}');
    }
    _activeCredentials = credentials;
  }

  Future<void> _leaveLinuxHotspot() async {
    final ssid = _activeCredentials?.ssid;
    if (ssid == null) return;
    await Process.run('nmcli', ['connection', 'delete', ssid]);
    _activeCredentials = null;
  }

  // ── Windows (netsh) ────────────────────────────────────────────────────────

  Future<HotspotCredentials> _startWindowsHotspot() async {
    final ssid = 'LocalSend-${_uuid.v4().substring(0, 6).toUpperCase()}';
    final passphrase = _uuid.v4().replaceAll('-', '').substring(0, 12);

    _logger.info('Creating Windows hosted network: $ssid');
    var result = await Process.run('netsh', [
      'wlan', 'set', 'hostednetwork',
      'mode=allow', 'ssid=$ssid', 'key=$passphrase',
    ]);
    if (result.exitCode != 0) {
      throw WifiDirectException('netsh set hostednetwork failed: ${result.stderr}');
    }

    result = await Process.run('netsh', ['wlan', 'start', 'hostednetwork']);
    if (result.exitCode != 0) {
      throw WifiDirectException('netsh start hostednetwork failed: ${result.stderr}');
    }

    _activeCredentials = HotspotCredentials(ssid: ssid, passphrase: passphrase);
    return _activeCredentials!;
  }

  Future<void> _stopWindowsHotspot() async {
    await Process.run('netsh', ['wlan', 'stop', 'hostednetwork']);
    _activeCredentials = null;
  }

  Future<void> _joinWindowsHotspot(HotspotCredentials credentials) async {
    // Windows auto-connects when the profile is added and the network is in range.
    // Using netsh wlan add profile + connect.
    final profileXml = '''<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>${credentials.ssid}</name>
  <SSIDConfig><SSID><name>${credentials.ssid}</name></SSID></SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>manual</connectionMode>
  <MSM><security>
    <authEncryption>
      <authentication>WPA2PSK</authentication>
      <encryption>AES</encryption>
      <useOneX>false</useOneX>
    </authEncryption>
    <sharedKey>
      <keyType>passPhrase</keyType>
      <protected>false</protected>
      <keyMaterial>${credentials.passphrase}</keyMaterial>
    </sharedKey>
  </security></MSM>
</WLANProfile>''';

    final profileFile = File('${Directory.systemTemp.path}\\ls_wifi_profile.xml');
    await profileFile.writeAsString(profileXml);

    var result = await Process.run('netsh', ['wlan', 'add', 'profile', 'filename=${profileFile.path}']);
    if (result.exitCode != 0) {
      throw WifiDirectException('Failed to add WiFi profile: ${result.stderr}');
    }

    result = await Process.run('netsh', ['wlan', 'connect', 'name=${credentials.ssid}']);
    if (result.exitCode != 0) {
      throw WifiDirectException('Failed to connect to ${credentials.ssid}: ${result.stderr}');
    }

    _activeCredentials = credentials;
    await profileFile.delete();
  }

  Future<void> _leaveWindowsHotspot() async {
    final ssid = _activeCredentials?.ssid;
    if (ssid == null) return;
    await Process.run('netsh', ['wlan', 'disconnect']);
    await Process.run('netsh', ['wlan', 'delete', 'profile', 'name=$ssid']);
    _activeCredentials = null;
  }
}
