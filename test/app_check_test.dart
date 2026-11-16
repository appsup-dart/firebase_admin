import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:firebase_admin/src/app_check/api_client.dart';
import 'package:firebase_admin/src/app_check/token_generator.dart';
import 'package:firebase_admin/src/app_check/token_verifier.dart';
import 'package:firebase_admin/src/auth/credential.dart';
import 'package:firebase_admin/testing.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jose/jose.dart';
import 'package:test/test.dart';

import 'resources/mocks.dart' as mocks;

const projectNumber = '12345678';
const appId = '12345678:app:ID';

Matcher throwsFirebaseAppCheckError([String? code]) =>
    throwsA(isA<FirebaseAppCheckError>().having((e) => e.code, 'code', code));

JsonWebKeySet _testJwks() => JsonWebKeySet.fromJson(json.decode(
    File('test/resources/openid-jwks.json').readAsStringSync()));

String generateAppCheckToken({
  List<String>? audience,
  String? issuer,
  String? subject,
  String? algorithm,
  Duration? expiresIn,
  Map<String, dynamic>? headerOverrides,
  Map<String, dynamic>? claimOverrides,
}) {
  final certificate =
      (FirebaseAdmin.instance.testCredentials() as ServiceAccountCredential)
          .certificate;

  final claims = <String, dynamic>{
    'aud':
        audience ?? ['projects/$projectNumber', 'projects/${mocks.projectId}'],
    'iss': issuer ?? 'https://firebaseappcheck.googleapis.com/$projectNumber',
    'sub': subject ?? appId,
    'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
    'exp': clock
            .now()
            .add(expiresIn ?? const Duration(hours: 1))
            .millisecondsSinceEpoch ~/
        1000,
    'one': 'uno',
    'two': 'dos',
    ...?claimOverrides,
  };

  if (algorithm != null && algorithm != 'RS256') {
    // Build a compact JWT with a non-RS256 header for content checks.
    final header = <String, dynamic>{
      'alg': algorithm,
      'typ': 'JWT',
      'kid': certificate.privateKey.keyId,
      ...?headerOverrides,
    };
    String encode(Object value) => base64Url
        .encode(utf8.encode(value is String ? value : json.encode(value)))
        .replaceAll('=', '');
    return '${encode(header)}.${encode(claims)}.${encode('sig')}';
  }

  final builder = JsonWebSignatureBuilder()
    ..jsonContent = claims
    ..setProtectedHeader('kid', certificate.privateKey.keyId)
    ..setProtectedHeader('typ', 'JWT');
  if (headerOverrides != null) {
    for (final entry in headerOverrides.entries) {
      builder.setProtectedHeader(entry.key, entry.value);
    }
  }
  builder.addRecipient(certificate.privateKey, algorithm: 'RS256');
  return builder.build().toCompactSerialization();
}

class MockAppCheckTokenVerifier extends AppCheckTokenVerifier {
  MockAppCheckTokenVerifier(App app) : super(app);

  @override
  Future<JsonWebKeyStore> getKeyStore() async {
    return JsonWebKeyStore()..addKeySet(_testJwks());
  }
}

void main() {
  final admin = FirebaseAdmin.instance;

  setUpAll(() {
    admin.setupTesting();
    AppCheckTokenVerifier.factory = (app) => MockAppCheckTokenVerifier(app);
  });

  tearDownAll(() {
    AppCheckTokenVerifier.factory = (app) => AppCheckTokenVerifier(app);
    AppCheckApiClient.factory = (app) => AppCheckApiClient(app);
    AppCheckTokenGenerator.factory = (app) => AppCheckTokenGenerator(app);
  });

  group('App.appCheck()', () {
    test('returns a cached AppCheck service', () {
      final app = admin.initializeApp(mocks.appOptions, 'app-check-accessor');
      final first = app.appCheck();
      final second = app.appCheck();
      expect(first, same(second));
      expect(first.app, same(app));
    });
  });

  group('AppCheck.verifyToken()', () {
    AppCheck appCheckFor(String name) =>
        admin.initializeApp(mocks.appOptions, name).appCheck();

    test('rejects an empty token', () async {
      await expectLater(
        appCheckFor('app-check-empty').verifyToken(''),
        throwsFirebaseAppCheckError('app-check/invalid-argument'),
      );
    });

    test('rejects an invalid token', () async {
      await expectLater(
        appCheckFor('app-check-invalid').verifyToken('invalid-token'),
        throwsFirebaseAppCheckError('app-check/invalid-argument'),
      );
    });

    test('rejects a token with incorrect algorithm', () async {
      final token = generateAppCheckToken(algorithm: 'PS256');
      await expectLater(
        appCheckFor('app-check-alg').verifyToken(token),
        throwsA(isA<FirebaseAppCheckError>()
            .having((e) => e.code, 'code', 'app-check/invalid-argument')
            .having(
                (e) => e.message, 'message', contains('incorrect algorithm'))),
      );
    });

    test('rejects a token with incorrect audience', () async {
      final token = generateAppCheckToken(audience: ['wrong-audience']);
      await expectLater(
        appCheckFor('app-check-aud').verifyToken(token),
        throwsA(isA<FirebaseAppCheckError>()
            .having((e) => e.code, 'code', 'app-check/invalid-argument')
            .having((e) => e.message, 'message',
                contains('"aud" (audience) claim'))),
      );
    });

    test('rejects a token with incorrect issuer', () async {
      final token = generateAppCheckToken(issuer: 'https://example.com/');
      await expectLater(
        appCheckFor('app-check-iss').verifyToken(token),
        throwsA(isA<FirebaseAppCheckError>()
            .having((e) => e.code, 'code', 'app-check/invalid-argument')
            .having(
                (e) => e.message, 'message', contains('"iss" (issuer) claim'))),
      );
    });

    test('rejects a token with empty subject', () async {
      final token = generateAppCheckToken(subject: '');
      await expectLater(
        appCheckFor('app-check-sub').verifyToken(token),
        throwsA(isA<FirebaseAppCheckError>()
            .having((e) => e.code, 'code', 'app-check/invalid-argument')
            .having(
                (e) => e.message, 'message', contains('empty string "sub"'))),
      );
    });

    test('rejects an expired token', () async {
      final token = generateAppCheckToken(
        expiresIn: const Duration(hours: -1),
      );
      await expectLater(
        appCheckFor('app-check-exp').verifyToken(token),
        throwsFirebaseAppCheckError('app-check/app-check-token-expired'),
      );
    });

    test('returns decoded claims for a valid token', () async {
      final token = generateAppCheckToken();
      final result = await appCheckFor('app-check-ok').verifyToken(token);

      expect(result.appId, appId);
      expect(result.subject, appId);
      expect(result.audience, contains('projects/${mocks.projectId}'));
      expect(result.issuer,
          startsWith('https://firebaseappcheck.googleapis.com/'));
      expect(result.issuedAt, isNotNull);
      expect(result.expiresAt, isNotNull);
      expect(result.alreadyConsumed, isNull);
      expect(result.claims['one'], 'uno');
    });
  });

  group('AppCheck.verifyToken(consume: true)', () {
    test('returns alreadyConsumed from the backend', () async {
      AppCheckApiClient.factory = (app) => AppCheckApiClient(
            app,
            MockClient((request) async {
              expect(request.url.path,
                  '/v1beta/projects/${mocks.projectId}:verifyAppCheckToken');
              expect(json.decode(request.body)['appCheckToken'], isNotEmpty);
              return http.Response(
                json.encode({'alreadyConsumed': true}),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          );

      final app = admin.initializeApp(mocks.appOptions, 'app-check-consume');
      final appCheck = app.appCheck();
      final token = generateAppCheckToken();
      final result = await appCheck.verifyToken(token, consume: true);

      expect(result.appId, appId);
      expect(result.alreadyConsumed, isTrue);

      AppCheckApiClient.factory = (app) => AppCheckApiClient(app);
    });
  });

  group('AppCheck.createToken()', () {
    test('exchanges a custom token for an App Check token', () async {
      AppCheckApiClient.factory = (app) => AppCheckApiClient(
            app,
            MockClient((request) async {
              expect(
                request.url.path,
                '/v1/projects/${mocks.projectId}/apps/$appId:exchangeCustomToken',
              );
              final body = json.decode(request.body) as Map<String, dynamic>;
              expect(body['customToken'], isNotEmpty);
              expect(body['limitedUse'], isTrue);
              expect(body['jti'], 'custom-jti');
              return http.Response(
                json.encode({
                  'token': 'exchanged-app-check-token',
                  'ttl': '3600s',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          );

      final app = admin.initializeApp(mocks.appOptions, 'app-check-create');
      final appCheck = app.appCheck();
      final minted = await appCheck.createToken(
        appId,
        ttl: const Duration(hours: 1),
        limitedUse: true,
        jti: 'custom-jti',
      );

      expect(minted.token, 'exchanged-app-check-token');
      expect(minted.ttl, const Duration(hours: 1));

      AppCheckApiClient.factory = (app) => AppCheckApiClient(app);
    });

    test('rejects ttl outside allowed range', () async {
      final app = admin.initializeApp(mocks.appOptions, 'app-check-ttl');
      final appCheck = app.appCheck();
      await expectLater(
        appCheck.createToken(appId, ttl: const Duration(minutes: 5)),
        throwsFirebaseAppCheckError('app-check/invalid-argument'),
      );
    });

    test('rejects jti without limitedUse', () async {
      final app = admin.initializeApp(mocks.appOptions, 'app-check-jti');
      final appCheck = app.appCheck();
      await expectLater(
        appCheck.createToken(appId, jti: 'x'),
        throwsFirebaseAppCheckError('app-check/invalid-argument'),
      );
    });
  });
}
