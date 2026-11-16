import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:googleapis/iam/v1.dart' as iam;
import 'package:googleapis/iamcredentials/v1.dart' as iamcredentials;
import 'package:jose/jose.dart';

import '../../firebase_admin.dart';
import '../auth/credential.dart';
import '../utils/api_request.dart';

const _firebaseAppCheckAudience =
    'https://firebaseappcheck.googleapis.com/google.firebase.appcheck.v1.TokenExchangeService';

/// Generates custom JWTs that can be exchanged for App Check tokens.
class AppCheckTokenGenerator {
  final App app;

  static AppCheckTokenGenerator Function(App app) factory =
      (app) => AppCheckTokenGenerator(app);

  AppCheckTokenGenerator(this.app);

  /// Creates a short-lived custom token for [appId], optionally embedding TTL.
  Future<String> createCustomToken(
    String appId, {
    Duration? ttl,
  }) async {
    if (appId.isEmpty) {
      throw const FirebaseAppCheckError.invalidArgument(
        '`appId` must be a non-empty string.',
      );
    }

    final customClaims = _validateTtl(ttl);
    final credential = app.options.credential;

    if (credential is ServiceAccountCredential &&
        credential.certificate.projectId == app.options.projectId) {
      final certificate = credential.certificate;
      final claims = _createCustomTokenPayload(
        appId,
        certificate.clientEmail,
        customClaims,
      );

      final builder = JsonWebSignatureBuilder()
        ..jsonContent = claims
        ..setProtectedHeader('typ', 'JWT')
        ..addRecipient(certificate.privateKey, algorithm: 'RS256');

      return builder.build().toCompactSerialization();
    }

    var serviceAccountId = app.options.serviceAccountId;
    if (serviceAccountId == null) {
      final iamApi = iam.IamApi(AuthorizedHttpClient(app));
      final accounts = await iamApi.projects.serviceAccounts
          .list('projects/${app.options.projectId}');
      final account = accounts.accounts!.firstWhereOrNull(
          (a) => a.email?.startsWith('firebase-adminsdk-') ?? false);
      serviceAccountId = account?.email;
    }

    if (serviceAccountId != null) {
      final claims =
          _createCustomTokenPayload(appId, serviceAccountId, customClaims);
      final client =
          iamcredentials.IAMCredentialsApi(AuthorizedHttpClient(app));
      final response = await client.projects.serviceAccounts.signJwt(
        iamcredentials.SignJwtRequest(payload: json.encode(claims)),
        'projects/-/serviceAccounts/$serviceAccountId',
      );
      return response.signedJwt!;
    }

    throw const FirebaseAppCheckError.invalidCredential(
      'Failed to determine service account ID. Initialize the SDK with service '
      'account credentials or specify a service account ID with '
      'iam.serviceAccounts.signBlob permission.',
    );
  }

  Map<String, dynamic> _createCustomTokenPayload(
    String appId,
    String serviceAccountId,
    Map<String, dynamic> customOptions,
  ) {
    final iat = clock.now();
    return {
      'iss': serviceAccountId,
      'sub': serviceAccountId,
      'app_id': appId,
      'aud': _firebaseAppCheckAudience,
      'iat': iat.millisecondsSinceEpoch ~/ 1000,
      'exp': iat.add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000,
      ...customOptions,
    };
  }

  /// Validates [ttl] and returns claims to embed in the custom token.
  Map<String, dynamic> _validateTtl(Duration? ttl) {
    if (ttl == null) return const {};

    if (ttl < const Duration(minutes: 30) || ttl > const Duration(days: 7)) {
      throw const FirebaseAppCheckError.invalidArgument(
        'ttl must be a duration between 30 minutes and 7 days (inclusive).',
      );
    }
    // Protobuf Duration string, e.g. "3600s".
    final seconds = ttl.inMilliseconds / 1000.0;
    final secondsString = seconds == seconds.roundToDouble()
        ? seconds.toInt().toString()
        : seconds.toString();
    return {'ttl': '${secondsString}s'};
  }
}
