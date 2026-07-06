import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:wakie_core/wakie_core.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('login_identity'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('claudeLoginEmail', () {
    test('reads oauthAccount.emailAddress, lowercased', () {
      final f = File('${tmp.path}/.claude.json')
        ..writeAsStringSync(jsonEncode({
          'oauthAccount': {'emailAddress': 'WakieDemo1@Gmail.com'},
        }));
      expect(claudeLoginEmail(f.path), 'wakiedemo1@gmail.com');
    });

    test('signed out / missing / corrupt read as null', () {
      final f = File('${tmp.path}/.claude.json')
        ..writeAsStringSync(jsonEncode({'projects': {}}));
      expect(claudeLoginEmail(f.path), isNull);
      expect(claudeLoginEmail('${tmp.path}/nope.json'), isNull);
      f.writeAsStringSync('{corrupt');
      expect(claudeLoginEmail(f.path), isNull);
    });
  });

  group('codexLoginEmail', () {
    String jwt(Map<String, dynamic> claims) {
      String b64(Object o) =>
          base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      return '${b64({'alg': 'none'})}.${b64(claims)}.sig';
    }

    test('decodes the id_token JWT email claim', () {
      final f = File('${tmp.path}/auth.json')
        ..writeAsStringSync(jsonEncode({
          'tokens': {'id_token': jwt({'email': 'Official@Gmail.com'})},
        }));
      expect(codexLoginEmail(f.path), 'official@gmail.com');
    });

    test('missing token / malformed JWT read as null', () {
      final f = File('${tmp.path}/auth.json')
        ..writeAsStringSync(jsonEncode({'tokens': {}}));
      expect(codexLoginEmail(f.path), isNull);
      f.writeAsStringSync(jsonEncode({
        'tokens': {'id_token': 'no-dots-here'},
      }));
      expect(codexLoginEmail(f.path), isNull);
      expect(codexLoginEmail('${tmp.path}/nope.json'), isNull);
    });
  });
}
