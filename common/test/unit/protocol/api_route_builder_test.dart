import 'package:common/api_route_builder.dart';
import 'package:common/model/device.dart';
import 'package:test/test.dart';

Device _makeDevice({
  String ip = '192.168.1.5',
  int port = 53317,
  bool https = true,
  String version = '2.1',
}) {
  return Device(
    signalingId: null,
    ip: ip,
    version: version,
    port: port,
    https: https,
    fingerprint: 'fp',
    alias: 'TestDevice',
    deviceModel: null,
    deviceType: DeviceType.mobile,
    download: false,
    discoveryMethods: {MulticastDiscovery()},
  );
}

void main() {
  group('ApiRoute path constants', () {
    test('v2 info path is correct', () {
      expect(ApiRoute.info.v2, equals('/api/localsend/v2/info'));
    });

    test('v1 info path is correct', () {
      expect(ApiRoute.info.v1, equals('/api/localsend/v1/info'));
    });

    test('v2 upload path is correct', () {
      expect(ApiRoute.upload.v2, equals('/api/localsend/v2/upload'));
    });

    test('v1 upload uses legacy "send" path', () {
      expect(ApiRoute.upload.v1, equals('/api/localsend/v1/send'));
    });

    test('v2 prepareUpload path is correct', () {
      expect(
        ApiRoute.prepareUpload.v2,
        equals('/api/localsend/v2/prepare-upload'),
      );
    });

    test('v1 prepareUpload uses legacy "send-request" path', () {
      expect(
        ApiRoute.prepareUpload.v1,
        equals('/api/localsend/v1/send-request'),
      );
    });
  });

  group('ApiRoute.target()', () {
    test('builds HTTPS v2 URL correctly', () {
      final device = _makeDevice(https: true, version: '2.1');
      final url = ApiRoute.info.target(device);
      expect(url, equals('https://192.168.1.5:53317/api/localsend/v2/info'));
    });

    test('builds HTTP URL when device is not HTTPS', () {
      final device = _makeDevice(https: false, version: '2.1');
      final url = ApiRoute.info.target(device);
      expect(url, startsWith('http://'));
    });

    test('uses v1 path when device version is 1.0', () {
      final device = _makeDevice(version: '1.0');
      final url = ApiRoute.upload.target(device);
      expect(url, contains('/v1/send'));
    });

    test('uses v2 path when device version is 2.1', () {
      final device = _makeDevice(version: '2.1');
      final url = ApiRoute.upload.target(device);
      expect(url, contains('/v2/upload'));
    });

    test('includes query parameters in URL', () {
      final device = _makeDevice();
      final url = ApiRoute.info.target(device, query: {'token': 'abc'});
      expect(url, contains('token=abc'));
    });

    test('uses correct port in URL', () {
      final device = _makeDevice(port: 12345);
      final url = ApiRoute.info.target(device);
      expect(url, contains(':12345'));
    });
  });

  group('ApiRoute.targetRaw()', () {
    test('builds HTTPS v2 URL', () {
      final url = ApiRoute.info.targetRaw('10.0.0.1', 53317, true, '2.1');
      expect(url, equals('https://10.0.0.1:53317/api/localsend/v2/info'));
    });

    test('builds HTTP v1 URL for old version', () {
      final url = ApiRoute.info.targetRaw('10.0.0.1', 53317, false, '1.0');
      expect(url, equals('http://10.0.0.1:53317/api/localsend/v1/info'));
    });
  });
}
