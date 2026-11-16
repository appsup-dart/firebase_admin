import 'package:jose/jose.dart';
import 'package:meta/meta.dart';

import '../../firebase_admin.dart';
import '../app/app_extension.dart';

const _appCheckIssuer = 'https://firebaseappcheck.googleapis.com/';
const _jwksUrl = 'https://firebaseappcheck.googleapis.com/v1/jwks';
const _algorithmRs256 = 'RS256';

/// Verifies Firebase App Check JWTs against the public App Check JWKS.
class AppCheckTokenVerifier {
  final App app;

  static AppCheckTokenVerifier Function(App app) factory =
      (app) => AppCheckTokenVerifier(app);

  AppCheckTokenVerifier(this.app);

  /// JWKS endpoint used to verify App Check token signatures.
  @visibleForTesting
  Uri get jwksUri => Uri.parse(_jwksUrl);

  /// Key store used for signature verification. Override in tests.
  @visibleForTesting
  Future<JsonWebKeyStore> getKeyStore() async {
    return JsonWebKeyStore()..addKeySetUrl(jwksUri);
  }

  /// Verifies the format and signature of a Firebase App Check token.
  Future<JsonWebToken> verifyToken(String token) async {
    if (token.isEmpty) {
      throw const FirebaseAppCheckError.invalidArgument(
        'Decoding App Check token failed. Make sure you passed '
        'the entire string JWT which represents the Firebase App Check token.',
      );
    }

    final projectId = _ensureProjectId();
    final decoded = _safeDecode(token);
    _verifyContent(decoded, projectId);
    return _verifySignature(token);
  }

  String _ensureProjectId() {
    try {
      final projectId = app.projectId;
      if (projectId.isEmpty) {
        throw const FirebaseAppCheckError.invalidCredential(
          'Must initialize app with a cert credential or set your Firebase project ID as the '
          'GOOGLE_CLOUD_PROJECT environment variable to verify an App Check token.',
        );
      }
      return projectId;
    } on FirebaseAuthError catch (e) {
      throw FirebaseAppCheckError.invalidCredential(e.message);
    }
  }

  _DecodedAppCheckJwt _safeDecode(String jwtToken) {
    try {
      final jws = JsonWebSignature.fromCompactSerialization(jwtToken);
      final claims =
          JsonWebTokenClaims.fromJson(jws.unverifiedPayload.jsonContent);
      return _DecodedAppCheckJwt(header: jws.commonHeader, claims: claims);
    } catch (_) {
      throw const FirebaseAppCheckError.invalidArgument(
        'Decoding App Check token failed. Make sure you passed '
        'the entire string JWT which represents the Firebase App Check token.',
      );
    }
  }

  void _verifyContent(_DecodedAppCheckJwt decoded, String projectId) {
    final header = decoded.header;
    final claims = decoded.claims;
    const projectIdMatchMessage =
        ' Make sure the App Check token comes from the same '
        'Firebase project as the service account used to authenticate this SDK.';
    final scopedProjectId = 'projects/$projectId';

    String? errorMessage;
    if (header.algorithm != _algorithmRs256) {
      errorMessage =
          'The provided App Check token has incorrect algorithm. Expected "'
          '$_algorithmRs256" but got "${header.algorithm}".';
    } else if (claims.audience == null ||
        claims.audience!.isEmpty ||
        !claims.audience!.contains(scopedProjectId)) {
      errorMessage =
          'The provided App Check token has incorrect "aud" (audience) claim. Expected "'
          '$scopedProjectId" but got "${claims.audience}".$projectIdMatchMessage';
    } else if (claims.issuer == null ||
        !claims.issuer!.toString().startsWith(_appCheckIssuer)) {
      errorMessage =
          'The provided App Check token has incorrect "iss" (issuer) claim.';
    } else if (claims.subject == null) {
      errorMessage =
          'The provided App Check token has no "sub" (subject) claim.';
    } else if (claims.subject!.isEmpty) {
      errorMessage =
          'The provided App Check token has an empty string "sub" (subject) claim.';
    }

    if (errorMessage != null) {
      throw FirebaseAppCheckError.invalidArgument(errorMessage);
    }
  }

  Future<JsonWebToken> _verifySignature(String jwtToken) async {
    try {
      final keyStore = await getKeyStore();
      final token = await JsonWebToken.decodeAndVerify(
        jwtToken,
        keyStore,
        allowedArguments: const [_algorithmRs256],
      );

      final validationErrors = token.claims.validate().toList();
      if (validationErrors.isNotEmpty) {
        final expired = validationErrors.any(
          (e) => e.toString().toLowerCase().contains('expired'),
        );
        if (expired) {
          throw const FirebaseAppCheckError.appCheckTokenExpired();
        }
        throw FirebaseAppCheckError.invalidArgument(
          validationErrors.first.toString(),
        );
      }
      return token;
    } on FirebaseAppCheckError {
      rethrow;
    } on JoseException catch (error) {
      throw _mapJoseException(error);
    } catch (error) {
      throw FirebaseAppCheckError.invalidArgument(error.toString());
    }
  }

  FirebaseAppCheckError _mapJoseException(JoseException error) {
    final message = error.message;
    final lower = message.toLowerCase();
    if (lower.contains('expired')) {
      return const FirebaseAppCheckError.appCheckTokenExpired();
    }
    if (lower.contains('could not decrypt/verify') ||
        lower.contains('invalid signature') ||
        lower.contains('no matching')) {
      // Jose collapses missing-kid and bad-signature into one failure mode.
      if (lower.contains('no matching') || lower.contains('kid')) {
        return const FirebaseAppCheckError.invalidArgument(
          'The provided App Check token has "kid" claim which does not '
          'correspond to a known public key. Most likely the provided App Check token '
          'is expired, so get a fresh token from your client app and try again.',
        );
      }
      return const FirebaseAppCheckError.invalidArgument(
        'The provided App Check token has invalid signature.',
      );
    }
    return FirebaseAppCheckError.invalidArgument(message);
  }
}

class _DecodedAppCheckJwt {
  final JoseHeader header;
  final JsonWebTokenClaims claims;

  _DecodedAppCheckJwt({required this.header, required this.claims});
}
