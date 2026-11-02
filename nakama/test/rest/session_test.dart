import 'dart:convert';
import 'dart:io';

import 'package:faker/faker.dart';
import 'package:nakama/nakama.dart';
import 'package:nakama/src/models/response_error.dart';
import 'package:test/test.dart';

import '../config.dart';

void main() {
  group('[REST] request-local authentication', () {
    late HttpServer server;
    late NakamaRestApiClient client;
    final headers = <String, String?>{};
    String token(String user) {
      String part(Object data) =>
          base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
      return '${part({'alg': 'none'})}.${part({
            'uid': user,
            'exp': 4102444800
          })}.test';
    }

    Session session(String user) =>
        Session.restore(token: token(user), refreshToken: token(user))!;
    setUp(() async {
      headers.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      client = NakamaRestApiClient.init(
          host: '127.0.0.1',
          port: server.port,
          serverKey: 'test-key',
          key: 'headers-${server.port}');
      server.listen((request) async {
        await request.drain<void>();
        headers[request.uri.path] =
            request.headers.value(HttpHeaders.authorizationHeader);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(
            request.uri.path.startsWith('/v2/rpc/')
                ? {'payload': '{}'}
                : {
                    'token': token('user'),
                    'refresh_token': token('user'),
                    'created': false
                  }));
        await request.response.close();
      });
    });
    tearDown(() => server.close(force: true));
    final basic = 'Basic ${base64Encode(utf8.encode('test-key:'))}';
    test('refresh uses the server key after an authenticated request',
        () async {
      await client.rpc(session: session('user'), id: 'first');
      await client.sessionRefresh(session: session('user'));
      expect(headers['/v2/rpc/first'], 'Bearer ${token('user')}');
      expect(headers['/v2/account/session/refresh'], basic);
    });
    test('login and RPC keep their headers in either invocation order',
        () async {
      await Future.wait<Object?>([
        client.authenticateDevice(deviceId: 'device'),
        client.rpc(session: session('user'), id: 'first'),
      ]);
      expect(headers['/v2/account/authenticate/device'], basic);
      expect(headers['/v2/rpc/first'], 'Bearer ${token('user')}');
      await Future.wait<Object?>([
        client.rpc(session: session('user'), id: 'second'),
        client.authenticateDevice(deviceId: 'device'),
      ]);
      expect(headers['/v2/account/authenticate/device'], basic);
      expect(headers['/v2/rpc/second'], 'Bearer ${token('user')}');
    });
    test('concurrent sessions retain their own bearer tokens', () async {
      await Future.wait<Object?>([
        client.rpc(session: session('alice'), id: 'alice'),
        client.rpc(session: session('bob'), id: 'bob'),
        client.sessionRefresh(session: session('alice')),
      ]);
      expect(headers['/v2/rpc/alice'], 'Bearer ${token('alice')}');
      expect(headers['/v2/rpc/bob'], 'Bearer ${token('bob')}');
      expect(headers['/v2/account/session/refresh'], basic);
    });
  });

  group('[REST] Test Session', () {
    late final NakamaRestApiClient client;

    setUpAll(() async {
      client = NakamaRestApiClient.init(
        host: kTestHost,
        ssl: false,
        serverKey: kTestServerKey,
      );
    });

    test('logging out of session works', () async {
      final session =
          await client.authenticateDevice(deviceId: faker.guid.guid());

      await client.sessionLogout(session: session);

      await expectLater(
        client.sessionRefresh(session: session),
        throwsA(
          isA<ResponseError>(),
        ),
      );
    });
  });
}

