import 'package:jose/jose.dart';

import '../firebase_admin.dart';
import 'app_check/api_client.dart';
import 'app_check/token_generator.dart';
import 'app_check/token_verifier.dart';
import 'service.dart';

/// App Check service for [app].
///
/// Do not construct directly — use [App.appCheck].
class AppCheck implements FirebaseService {
  @override
  final App app;

  final AppCheckTokenVerifier _tokenVerifier;
  final AppCheckTokenGenerator _tokenGenerator;
  final AppCheckApiClient _apiClient;

  /// Do not call this constructor directly. Instead, use [App.appCheck].
  AppCheck(this.app)
      : _tokenVerifier = AppCheckTokenVerifier.factory(app),
        _tokenGenerator = AppCheckTokenGenerator.factory(app),
        _apiClient = AppCheckApiClient.factory(app);

  /// Verifies a Firebase App Check token (JWT).
  ///
  /// On success returns the decoded claims as [VerifyAppCheckTokenResult].
  /// When [consume] is true, also returns
  /// [VerifyAppCheckTokenResult.alreadyConsumed] from the App Check backend
  /// (replay protection). Throws [FirebaseAppCheckError] otherwise.
  Future<VerifyAppCheckTokenResult> verifyToken(
    String appCheckToken, {
    bool consume = false,
  }) async {
    final token = await _tokenVerifier.verifyToken(appCheckToken);
    if (consume) {
      final alreadyConsumed =
          await _apiClient.verifyReplayProtection(appCheckToken);
      return VerifyAppCheckTokenResult._fromVerified(
        token,
        alreadyConsumed: alreadyConsumed,
      );
    }
    return VerifyAppCheckTokenResult._fromVerified(token);
  }

  /// Creates an App Check token for [appId] (Firebase App ID) for custom providers.
  ///
  /// [ttl] must be between 30 minutes and 7 days when set (default 1 hour).
  /// [jti] is only valid when [limitedUse] is true.
  Future<AppCheckToken> createToken(
    String appId, {
    Duration? ttl,
    bool limitedUse = false,
    String? jti,
  }) async {
    final customToken = await _tokenGenerator.createCustomToken(
      appId,
      ttl: ttl,
    );
    return _apiClient.exchangeToken(
      customToken,
      appId,
      limitedUse: limitedUse,
      jti: jti,
    );
  }

  @override
  Future<void> delete() async {}
}

/// Minted token returned by [AppCheck.createToken].
class AppCheckToken {
  final String token;
  final Duration ttl;

  const AppCheckToken({required this.token, required this.ttl});
}

/// Result of [AppCheck.verifyToken].
///
/// Exposes the App Check claims used by callers; does not leak the JWT library
/// type used for verification. [alreadyConsumed] is only set when verify was
/// called with `consume: true`.
class VerifyAppCheckTokenResult {
  /// Firebase App ID (`sub`).
  final String appId;

  /// JWT `sub` claim — same value as [appId].
  String get subject => appId;

  /// JWT `aud` claim.
  final List<String> audience;

  /// JWT `iss` claim.
  final String issuer;

  /// JWT `iat` claim, if present.
  final DateTime? issuedAt;

  /// JWT `exp` claim, if present.
  final DateTime? expiresAt;

  /// Full JWT payload, including standard claims.
  final Map<String, dynamic> claims;

  /// Present when verify was called with `consume: true`.
  ///
  /// This is a backend response (whether the token was previously consumed),
  /// not an echo of the caller's [AppCheck.verifyToken] `consume` argument.
  final bool? alreadyConsumed;

  VerifyAppCheckTokenResult._({
    required this.appId,
    required List<String> audience,
    required this.issuer,
    required this.issuedAt,
    required this.expiresAt,
    required Map<String, dynamic> claims,
    required this.alreadyConsumed,
  })  : audience = List.unmodifiable(audience),
        claims = Map.unmodifiable(claims);

  factory VerifyAppCheckTokenResult._fromVerified(
    JsonWebToken token, {
    bool? alreadyConsumed,
  }) {
    final c = token.claims;
    return VerifyAppCheckTokenResult._(
      appId: c.subject!,
      audience: c.audience ?? const [],
      issuer: c.issuer.toString(),
      issuedAt: c.issuedAt,
      expiresAt: c.expiry,
      claims: c.toJson(),
      alreadyConsumed: alreadyConsumed,
    );
  }
}
