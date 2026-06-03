import 'package:common/constants.dart';
import 'package:test/test.dart';

void main() {
  group('Protocol constants', () {
    test('default port is 53317', () {
      expect(defaultPort, equals(53317));
    });

    test('default multicast group is the correct IPv4 address', () {
      expect(defaultMulticastGroup, equals('224.0.0.167'));
    });

    test('current protocol version is 2.1', () {
      expect(protocolVersion, equals('2.1'));
    });

    test('peer protocol version for first handshake is 1.0', () {
      // Peers are assumed to speak the older version until they announce otherwise.
      expect(peerProtocolVersion, equals('1.0'));
    });

    test('fallback protocol version is 1.0', () {
      expect(fallbackProtocolVersion, equals('1.0'));
    });

    test('default discovery timeout is positive', () {
      expect(defaultDiscoveryTimeout, greaterThan(0));
    });
  });
}
