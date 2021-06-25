import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:firebase_admin/src/auth/credential.dart';
import 'package:firebase_admin/src/auth/token_verifier.dart';
import 'package:firebase_admin/src/credential.dart';
import 'package:jose/jose.dart';
import 'package:openid_client/openid_client.dart' hide Credential;
import 'package:path/path.dart' as path;
import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_admin/src/app.dart';

var projectId = 'project_id';

var appName = 'mock-app-name';

var databaseURL = 'https://databaseName.firebaseio.com';

var storageBucket = 'bucketName.appspot.com';

var credential = ServiceAccountMockCredential(
    path.join(path.current, 'test/resources/mock.key.json'));

class ServiceAccountMockCredential extends ServiceAccountCredential
    with MockCredentialMixin {
  @override
  final AccessToken Function() tokenFactory;
  ServiceAccountMockCredential(serviceAccountPathOrObject,
      [this.tokenFactory = MockCredentialMixin.defaultFactory])
      : super(serviceAccountPathOrObject);
}

class MockCredential extends Credential with MockCredentialMixin {
  @override
  final AccessToken Function() tokenFactory;

  MockCredential([this.tokenFactory = MockCredentialMixin.defaultFactory]);
}

mixin MockCredentialMixin on Credential {
  AccessToken Function() get tokenFactory;

  static AccessToken defaultFactory() => MockAccessToken.fromJson({
        'access_token': 'mock-access-token',
        'expires_in': 3600,
      });

  int _callCount = 0;

  static int getCallCount(App app) {
    return (app.internals.credential as MockCredentialMixin)._callCount;
  }

  static void resetCallCount(App app) {
    (app.internals.credential as MockCredentialMixin)._callCount = 0;
  }

  @override
  Future<AccessToken> getAccessToken() async {
    _callCount++;
    return tokenFactory();
  }
}

var appOptions = AppOptions(
  credential: credential,
  databaseUrl: databaseURL,
  storageBucket: storageBucket,
);

var appOptionsWithOverride = AppOptions(
  credential: credential,
  databaseUrl: databaseURL,
  storageBucket: storageBucket,
  projectId: projectId,
);

var appOptionsNoDatabaseUrl = AppOptions(
  credential: credential,
);

var appOptionsAuthDB = AppOptions(
  credential: credential,
  databaseUrl: databaseURL,
);

final appOptionsReturningNullAccessToken = AppOptions(
    credential: MockCredential(() => null),
    databaseUrl: databaseURL,
    projectId: projectId);

final appOptionsRejectedWhileFetchingAccessToken = AppOptions(
    credential: MockCredential(
        () => throw Exception('Promise intentionally rejected.')),
    databaseUrl: databaseURL,
    projectId: projectId);

final certificateObject =
    ServiceAccountCredential('test/resources/mock.key.json');

const uid = 'someUid';

/// Generates a mocked Firebase ID token.
String generateIdToken([Map<String, dynamic> overrides]) {
  overrides ??= {};
  final claims = {
    'aud': projectId,
    'exp': clock.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
    'iss': 'https://securetoken.google.com/' + projectId,
    'sub': uid,
    'auth_time': clock.now().millisecondsSinceEpoch ~/ 1000,
    ...overrides,
  };

  var builder = JsonWebSignatureBuilder()
    ..jsonContent = claims
    ..setProtectedHeader('kid', certificateObject.certificate.privateKey.keyId)
    ..addRecipient(certificateObject.certificate.privateKey,
        algorithm: 'RS256');

  return builder.build().toCompactSerialization();
}

class MockTokenVerifier extends FirebaseTokenVerifier {
  MockTokenVerifier(App app) : super(app);

  @override
  Future<Client> getOpenIdClient() async {
    var config = json.decode(
        File('test/resources/openid-configuration.json').readAsStringSync());

    var uri = Uri.parse(config['jwks_uri']);
    if (uri.scheme.isEmpty) {
      var content = File(uri.toFilePath()).readAsStringSync();
      config['jwks_uri'] =
          Uri.dataFromString(content, mimeType: 'application/json').toString();
    }

    var issuer = Issuer(OpenIdProviderMetadata.fromJson(config));
    return Client(issuer, projectId);
  }
}

class MockAccessToken implements AccessToken {
  @override
  final String accessToken;

  @override
  final DateTime expirationTime;

  MockAccessToken({this.accessToken, Duration expiresIn})
      : expirationTime = expiresIn == null ? null : clock.now().add(expiresIn);

  MockAccessToken.fromJson(Map<String, dynamic> json)
      : this(
            accessToken: json['access_token'],
            expiresIn: Duration(seconds: json['expires_in']));
}
