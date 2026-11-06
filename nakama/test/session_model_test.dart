import 'dart:convert';

import 'package:nakama/src/api/api.dart' as dto;
import 'package:nakama/src/models/session.dart';
import 'package:nakama/src/rest/api_client.gen.dart';
import 'package:test/test.dart';

String _token(Map<String, dynamic> claims) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

  return '${part({'alg': 'none'})}.${part(claims)}.test';
}

void main() {
  final factories = <String, Session Function(String, String)>{
    'fromApi': (token, refreshToken) => Session.fromApi(ApiSession(
          token: token,
          refreshToken: refreshToken,
          created: false,
        )),
    'fromDto': (token, refreshToken) => Session.fromDto(dto.Session(
          token: token,
          refreshToken: refreshToken,
          created: false,
        )),
  };
  const claims = <String, dynamic>{'uid': 'user-id', 'exp': 4102444800};
  final refreshToken = _token(claims);

  for (final factory in factories.entries) {
    group('Session.${factory.key}', () {
      test('decodes recovery variables from a JSON JWT payload', () {
        const vars = {
          'accountRecoveryNativeLinked': 'false',
          'accountRecoverySupportId': 'public-id',
        };
        final token = _token({...claims, 'vars': vars});

        final session = factory.value(token, refreshToken);

        expect(session.vars, vars);
        expect(session.userId, 'user-id');
        expect(session.token, token);
        expect(session.refreshToken, refreshToken);
        expect(session.created, isFalse);
        expect(session.expiresAt.millisecondsSinceEpoch, 4102444800000);
        expect(session.refreshExpiresAt.millisecondsSinceEpoch, 4102444800000);
      });

      test('preserves an empty map when variables are absent', () {
        final session = factory.value(_token(claims), refreshToken);

        expect(session.vars, isEmpty);
      });

      test('preserves explicitly null variables', () {
        final session =
            factory.value(_token({...claims, 'vars': null}), refreshToken);

        expect(session.vars, isNull);
      });
    });
  }
}
