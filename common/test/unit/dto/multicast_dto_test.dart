import 'dart:convert';

import 'package:common/constants.dart';
import 'package:common/model/device.dart';
import 'package:common/model/dto/multicast_dto.dart';
import 'package:test/test.dart';

void main() {
  group('MulticastDto', () {
    test('parses full v2 JSON correctly', () {
      final json =
          jsonDecode('''{
        "alias": "TestPhone",
        "version": "2.1",
        "deviceModel": "Pixel 7",
        "deviceType": "mobile",
        "fingerprint": "abc123",
        "port": 53317,
        "protocol": "https",
        "download": false,
        "announce": true
      }''')
              as Map<String, dynamic>;

      final dto = MulticastDto.fromJson(json);

      expect(dto.alias, equals('TestPhone'));
      expect(dto.version, equals('2.1'));
      expect(dto.deviceModel, equals('Pixel 7'));
      expect(dto.deviceType, equals(DeviceType.mobile));
      expect(dto.fingerprint, equals('abc123'));
      expect(dto.port, equals(53317));
      expect(dto.protocol, equals(ProtocolType.https));
      expect(dto.download, isFalse);
      expect(dto.announce, isTrue);
    });

    test('parses v1 JSON without optional fields', () {
      final json =
          jsonDecode('''{
        "alias": "OldDevice",
        "version": null,
        "deviceModel": null,
        "deviceType": null,
        "fingerprint": "xyz789",
        "port": null,
        "protocol": null,
        "download": null,
        "announcement": true
      }''')
              as Map<String, dynamic>;

      final dto = MulticastDto.fromJson(json);

      expect(dto.alias, equals('OldDevice'));
      expect(dto.version, isNull);
      expect(dto.fingerprint, equals('xyz789'));
      expect(dto.announcement, isTrue);
      expect(dto.announce, isNull);
    });

    test('toDevice uses own port when DTO port is null (v1 compat)', () {
      final json =
          jsonDecode('''{
        "alias": "LegacyDevice",
        "version": null,
        "deviceModel": null,
        "deviceType": null,
        "fingerprint": "fp1",
        "port": null,
        "protocol": null,
        "download": null,
        "announcement": null,
        "announce": null
      }''')
              as Map<String, dynamic>;

      final dto = MulticastDto.fromJson(json);
      final device = dto.toDevice('192.168.1.10', 53317, true);

      expect(device.ip, equals('192.168.1.10'));
      expect(device.port, equals(53317));
      expect(device.https, isTrue);
      expect(device.version, equals(fallbackProtocolVersion));
      expect(device.deviceType, equals(DeviceType.desktop));
      expect(device.download, isFalse);
    });

    test('toDevice uses DTO port and protocol when provided', () {
      final json =
          jsonDecode('''{
        "alias": "ModernDevice",
        "version": "2.1",
        "deviceModel": "MacBook",
        "deviceType": "desktop",
        "fingerprint": "fp2",
        "port": 12345,
        "protocol": "http",
        "download": true,
        "announcement": null,
        "announce": false
      }''')
              as Map<String, dynamic>;

      final dto = MulticastDto.fromJson(json);
      final device = dto.toDevice('10.0.0.5', 53317, true);

      expect(device.port, equals(12345));
      expect(device.https, isFalse);
      expect(device.version, equals('2.1'));
      expect(device.download, isTrue);
      expect(device.discoveryMethods, contains(MulticastDiscovery()));
    });

    test('own fingerprint is intended to be filtered by caller', () {
      // The DTO itself does not know the own fingerprint — filtering
      // is the responsibility of the multicast listener, not the DTO.
      final json =
          jsonDecode('''{
        "alias": "Self",
        "version": "2.1",
        "deviceModel": null,
        "deviceType": "mobile",
        "fingerprint": "self_fp",
        "port": 53317,
        "protocol": "https",
        "download": false,
        "announcement": null,
        "announce": false
      }''')
              as Map<String, dynamic>;

      final dto = MulticastDto.fromJson(json);
      expect(dto.fingerprint, equals('self_fp'));
    });
  });
}
