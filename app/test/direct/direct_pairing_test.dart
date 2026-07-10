import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/provider/direct/direct_pairing.dart';

void main() {
  group('PairingPayload lsd:// round-trip', () {
    test('encodes and decodes a full payload', () {
      const original = PairingPayload(
        ssid: 'LocalSend-AB12',
        password: 's3cr3tpass',
        host: '192.168.49.1',
        port: 53317,
        protocol: 'https',
        fingerprint: 'ab:cd:ef',
        sessionToken: 'tok-123',
      );

      final uri = original.toUri();
      expect(uri.startsWith('lsd://v1/'), isTrue);

      final parsed = PairingPayload.tryParse(uri);
      expect(parsed, isNotNull);
      expect(parsed!.ssid, original.ssid);
      expect(parsed.password, original.password);
      expect(parsed.host, original.host);
      expect(parsed.port, original.port);
      expect(parsed.protocol, 'https');
      expect(parsed.fingerprint, 'ab:cd:ef');
      expect(parsed.sessionToken, 'tok-123');
      expect(parsed.canConnectDirectly, isTrue);
      expect(parsed.baseUrl, 'https://192.168.49.1:53317');
    });

    test('handles minimal payload without host/port', () {
      const original = PairingPayload(ssid: 'S', password: 'P');
      final parsed = PairingPayload.tryParse(original.toUri());
      expect(parsed, isNotNull);
      expect(parsed!.canConnectDirectly, isFalse);
      expect(parsed.baseUrl, isNull);
    });

    test('preserves special characters in credentials', () {
      const original = PairingPayload(
        ssid: 'Net;work:name,x',
        password: r'p@ss;:,\word',
      );
      final parsed = PairingPayload.tryParse(original.toUri());
      expect(parsed!.ssid, original.ssid);
      expect(parsed.password, original.password);
    });
  });

  group('PairingPayload WIFI: fallback', () {
    test('round-trips ssid and password', () {
      const original = PairingPayload(ssid: 'MyNet', password: 'MyPass');
      final wifi = original.toWifiQr();
      expect(wifi.startsWith('WIFI:'), isTrue);

      final parsed = PairingPayload.tryParse(wifi);
      expect(parsed, isNotNull);
      expect(parsed!.ssid, 'MyNet');
      expect(parsed.password, 'MyPass');
      expect(parsed.canConnectDirectly, isFalse);
    });

    test('unescapes special characters', () {
      const original = PairingPayload(ssid: 'a;b:c', password: r'x,y\z');
      final parsed = PairingPayload.tryParse(original.toWifiQr());
      expect(parsed!.ssid, 'a;b:c');
      expect(parsed.password, r'x,y\z');
    });
  });

  group('PairingPayload.tryParse rejects junk', () {
    test('returns null for unrelated strings', () {
      expect(PairingPayload.tryParse('https://example.com'), isNull);
      expect(PairingPayload.tryParse('random text'), isNull);
      expect(PairingPayload.tryParse(''), isNull);
    });

    test('returns null for malformed lsd payload', () {
      expect(PairingPayload.tryParse('lsd://v1/not-base64!!!'), isNull);
      expect(PairingPayload.tryParse('lsd://v1'), isNull);
    });
  });
}
