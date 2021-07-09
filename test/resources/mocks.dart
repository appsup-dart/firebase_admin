import 'package:clock/clock.dart';
import 'package:firebase_admin/src/auth/credential.dart';
import 'package:firebase_admin/src/testing.dart';
import 'package:jose/jose.dart';
import 'package:firebase_admin/testing.dart';
import 'package:firebase_admin/src/app.dart';

var projectId = 'project_id';

var appName = 'mock-app-name';

var databaseURL = 'https://databaseName.firebaseio.com';

var storageBucket = 'bucketName.appspot.com';

var credential = FirebaseAdmin.instance.testCredentials();

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

final appOptionsRejectedWhileFetchingAccessToken = AppOptions(
    credential: MockCredential(
        () => throw Exception('Promise intentionally rejected.')),
    databaseUrl: databaseURL,
    projectId: projectId);

final certificateObject = credential as ServiceAccountCredential;

const uid = 'someUid';

/// Generates a mocked Firebase ID token.
String generateIdToken([Map<String, dynamic>? overrides]) {
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
