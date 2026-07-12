// Unit tests for the VLESS share-link parser.
//
// NOTE ON IMPORTS: this project keeps its packages at the repo root (core/,
// data/, …) rather than under lib/, so there is no `package:fastflow_vpn/`
// URI for them. Tests therefore reach the code under test with relative
// imports, matching how the app's own files import each other.
import 'package:flutter_test/flutter_test.dart';

import '../core/domain/enums/flow_type.dart';
import '../core/domain/models/proxy_profile.dart';
import '../core/parsing/vless_parser.dart';

void main() {
  group('VlessParser.parse — happy path', () {
    test('minimal link: uuid + host, port defaults to 443', () {
      final p = VlessParser.parse('vless://11111111-2222-3333-4444-555555555555@example.com');

      expect(p.protocol, ProxyProtocol.vless);
      expect(p.uuid, '11111111-2222-3333-4444-555555555555');
      expect(p.serverAddress, 'example.com');
      expect(p.port, 443);
      // No fragment → the name falls back to the host.
      expect(p.name, 'example.com');
    });

    test('explicit port is honoured', () {
      final p = VlessParser.parse('vless://uuid@example.com:8443');
      expect(p.port, 8443);
    });

    test('fragment becomes the profile name (percent-decoded)', () {
      final p = VlessParser.parse('vless://uuid@host:443#My%20Server%20%F0%9F%87%A9%F0%9F%87%AA');
      expect(p.name, 'My Server 🇩🇪');
    });

    test('percent-encoded userInfo is decoded into the uuid', () {
      // Not typical for a UUID, but the parser must decode userInfo.
      final p = VlessParser.parse('vless://user%40name@host');
      expect(p.uuid, 'user@name');
    });

    test('surrounding whitespace is trimmed', () {
      final p = VlessParser.parse('   vless://uuid@host:443   ');
      expect(p.serverAddress, 'host');
      expect(p.port, 443);
    });

    test('scheme is matched case-insensitively', () {
      final p = VlessParser.parse('VLESS://uuid@host');
      expect(p.serverAddress, 'host');
    });
  });

  group('security / TLS', () {
    test('security=reality fills Reality + defaults fingerprint to chrome', () {
      final p = VlessParser.parse(
        'vless://uuid@host:443?security=reality&pbk=PUBKEY&sid=ab12',
      );

      expect(p.tls.enabled, isTrue);
      expect(p.tls.reality.enabled, isTrue);
      expect(p.tls.reality.publicKey, 'PUBKEY');
      expect(p.tls.reality.shortId, 'ab12');
      // Reality with no explicit fp → chrome.
      expect(p.tls.utlsFingerprint, 'chrome');
    });

    test('explicit fp overrides the reality default', () {
      final p = VlessParser.parse('vless://uuid@host?security=reality&fp=firefox');
      expect(p.tls.utlsFingerprint, 'firefox');
    });

    test('security=tls enables TLS but not Reality', () {
      final p = VlessParser.parse('vless://uuid@host?security=tls');
      expect(p.tls.enabled, isTrue);
      expect(p.tls.reality.enabled, isFalse);
    });

    test('no security → TLS disabled, no uTLS fingerprint', () {
      final p = VlessParser.parse('vless://uuid@host');
      expect(p.tls.enabled, isFalse);
      expect(p.tls.utlsFingerprint, '');
    });

    test('sni falls back to the "peer" alias', () {
      final withSni = VlessParser.parse('vless://uuid@host?security=tls&sni=a.example');
      expect(withSni.tls.sni, 'a.example');

      final withPeer = VlessParser.parse('vless://uuid@host?security=tls&peer=b.example');
      expect(withPeer.tls.sni, 'b.example');
    });

    test('alpn is split on commas and trimmed; empty falls back to a default', () {
      final custom = VlessParser.parse('vless://uuid@host?security=tls&alpn=h3,%20h2');
      expect(custom.tls.alpn, ['h3', 'h2']);

      final none = VlessParser.parse('vless://uuid@host?security=tls');
      expect(none.tls.alpn, ['h2', 'http/1.1']);
    });

    test('allowInsecure / insecure are parsed as booleans', () {
      expect(VlessParser.parse('vless://uuid@host?allowInsecure=1').tls.allowInsecure, isTrue);
      expect(VlessParser.parse('vless://uuid@host?insecure=true').tls.allowInsecure, isTrue);
      expect(VlessParser.parse('vless://uuid@host?allowInsecure=yes').tls.allowInsecure, isTrue);
      expect(VlessParser.parse('vless://uuid@host?allowInsecure=0').tls.allowInsecure, isFalse);
      expect(VlessParser.parse('vless://uuid@host').tls.allowInsecure, isFalse);
    });
  });

  group('transport', () {
    test('type maps to the right TransportType', () {
      TransportType typeOf(String t) =>
          VlessParser.parse('vless://uuid@host?type=$t').transport.type;

      expect(typeOf('ws'), TransportType.ws);
      expect(typeOf('grpc'), TransportType.grpc);
      expect(typeOf('http'), TransportType.http);
      expect(typeOf('h2'), TransportType.http); // alias
      expect(typeOf('httpupgrade'), TransportType.httpUpgrade);
      expect(typeOf('quic'), TransportType.quic);
      expect(typeOf('tcp'), TransportType.tcp);
    });

    test('missing/unknown type defaults to tcp', () {
      expect(VlessParser.parse('vless://uuid@host').transport.type, TransportType.tcp);
      expect(
        VlessParser.parse('vless://uuid@host?type=carrier-pigeon').transport.type,
        TransportType.tcp,
      );
    });

    test('ws path/host header are carried through', () {
      final p = VlessParser.parse('vless://uuid@host?type=ws&path=/vpn&host=cdn.example');
      expect(p.transport.path, '/vpn');
      expect(p.transport.host, 'cdn.example');
    });

    test('empty/absent path defaults to "/"', () {
      expect(VlessParser.parse('vless://uuid@host?type=ws').transport.path, '/');
      expect(VlessParser.parse('vless://uuid@host?type=ws&path=').transport.path, '/');
    });

    test('grpc serviceName accepts both camelCase and lowercase keys', () {
      expect(
        VlessParser.parse('vless://uuid@host?type=grpc&serviceName=svc').transport.serviceName,
        'svc',
      );
      expect(
        VlessParser.parse('vless://uuid@host?type=grpc&servicename=svc2').transport.serviceName,
        'svc2',
      );
    });
  });

  group('flow', () {
    test('xtls-rprx-vision is recognised', () {
      final p = VlessParser.parse('vless://uuid@host?flow=xtls-rprx-vision');
      expect(p.flow, FlowType.xtlsRprxVision);
    });

    test('absent/unknown flow → none', () {
      expect(VlessParser.parse('vless://uuid@host').flow, FlowType.none);
      expect(VlessParser.parse('vless://uuid@host?flow=bogus').flow, FlowType.none);
    });
  });

  group('parse — error cases (throw FormatException)', () {
    test('non-vless scheme', () {
      expect(
        () => VlessParser.parse('trojan://uuid@host'),
        throwsFormatException,
      );
    });

    test('missing uuid before @', () {
      expect(() => VlessParser.parse('vless://@host:443'), throwsFormatException);
    });

    test('missing host', () {
      expect(() => VlessParser.parse('vless://uuid@'), throwsFormatException);
    });

    test('malformed URI (non-numeric port)', () {
      expect(() => VlessParser.parse('vless://uuid@host:notaport'), throwsFormatException);
    });

    test('empty string', () {
      expect(() => VlessParser.parse(''), throwsFormatException);
    });
  });

  group('tryParse — never throws', () {
    test('returns a profile for valid input', () {
      expect(VlessParser.tryParse('vless://uuid@host'), isA<ProxyProfile>());
    });

    test('returns null for every invalid input', () {
      expect(VlessParser.tryParse('not a link'), isNull);
      expect(VlessParser.tryParse('trojan://uuid@host'), isNull);
      expect(VlessParser.tryParse('vless://@host'), isNull);
      expect(VlessParser.tryParse('vless://uuid@'), isNull);
      expect(VlessParser.tryParse(''), isNull);
    });
  });

  group('full round-trip link', () {
    test('a realistic Reality + Vision link parses every field', () {
      const link =
          'vless://uuid-abc@vpn.example.com:443?type=tcp&security=reality'
          '&pbk=PBKEY&sid=00ff&fp=chrome&flow=xtls-rprx-vision&sni=www.microsoft.com'
          '#Prod%20Node';

      final p = VlessParser.parse(link);

      expect(p.uuid, 'uuid-abc');
      expect(p.serverAddress, 'vpn.example.com');
      expect(p.port, 443);
      expect(p.transport.type, TransportType.tcp);
      expect(p.tls.enabled, isTrue);
      expect(p.tls.reality.enabled, isTrue);
      expect(p.tls.reality.publicKey, 'PBKEY');
      expect(p.tls.reality.shortId, '00ff');
      expect(p.tls.sni, 'www.microsoft.com');
      expect(p.tls.utlsFingerprint, 'chrome');
      expect(p.flow, FlowType.xtlsRprxVision);
      expect(p.name, 'Prod Node');
    });
  });
}
