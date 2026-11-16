import 'package:_discoveryapis_commons/_discoveryapis_commons.dart';
import 'package:googleapis/firebaseappcheck/v1.dart' as appcheck_v1;
import 'package:googleapis_beta/firebaseappcheck/v1beta.dart'
    as appcheck_v1beta;
import 'package:http/http.dart' as http;

import '../../firebase_admin.dart';
import '../app/app_extension.dart';
import '../utils/api_request.dart';

/// Client for the Firebase App Check backend API.
///
/// Minting uses stable [appcheck_v1.FirebaseappcheckApi]; replay-protection
/// consume uses [appcheck_v1beta.FirebaseappcheckApi] (still v1beta only).
class AppCheckApiClient {
  final App app;
  final appcheck_v1.FirebaseappcheckApi _v1;
  final appcheck_v1beta.FirebaseappcheckApi _v1beta;

  static AppCheckApiClient Function(App app) factory =
      (app) => AppCheckApiClient(app);

  AppCheckApiClient(App app, [http.Client? httpClient])
      : this._(app, httpClient ?? AuthorizedHttpClient(app));

  AppCheckApiClient._(this.app, http.Client client)
      : _v1 = appcheck_v1.FirebaseappcheckApi(client),
        _v1beta = appcheck_v1beta.FirebaseappcheckApi(client);

  /// Exchanges a signed custom token for an App Check token.
  Future<AppCheckToken> exchangeToken(
    String customToken,
    String appId, {
    bool limitedUse = false,
    String? jti,
  }) async {
    if (appId.isEmpty) {
      throw const FirebaseAppCheckError.invalidArgument(
        '`appId` must be a non-empty string.',
      );
    }
    if (customToken.isEmpty) {
      throw const FirebaseAppCheckError.invalidArgument(
        '`customToken` must be a non-empty string.',
      );
    }
    if (jti != null && !limitedUse) {
      throw const FirebaseAppCheckError.invalidArgument(
        '`jti` cannot be specified without setting `limitedUse` to `true`.',
      );
    }

    final projectId = _getProjectId();
    final request = appcheck_v1.GoogleFirebaseAppcheckV1ExchangeCustomTokenRequest(
      customToken: customToken,
      limitedUse: limitedUse ? true : null,
      jti: jti,
    );

    try {
      final response = await _v1.projects.apps.exchangeCustomToken(
        request,
        'projects/$projectId/apps/$appId',
      );
      return _toAppCheckToken(response);
    } on DetailedApiRequestError catch (error) {
      throw _fromApiError(error);
    }
  }

  /// Marks [token] as consumed and returns whether it was already consumed.
  Future<bool> verifyReplayProtection(String token) async {
    if (token.isEmpty) {
      throw const FirebaseAppCheckError.invalidArgument(
        '`token` must be a non-empty string.',
      );
    }

    final projectId = _getProjectId();
    try {
      final response = await _v1beta.projects.verifyAppCheckToken(
        appcheck_v1beta.GoogleFirebaseAppcheckV1betaVerifyAppCheckTokenRequest(
          appCheckToken: token,
        ),
        'projects/$projectId',
      );
      return response.alreadyConsumed == true;
    } on DetailedApiRequestError catch (error) {
      throw _fromApiError(error);
    }
  }

  String _getProjectId() {
    try {
      final projectId = app.projectId;
      if (projectId.isEmpty) {
        throw const FirebaseAppCheckError.unknownError(
          'Failed to determine project ID. Initialize the '
          'SDK with service account credentials or set project ID as an app option. '
          'Alternatively, set the GOOGLE_CLOUD_PROJECT environment variable.',
        );
      }
      return projectId;
    } on FirebaseAuthError catch (_) {
      throw const FirebaseAppCheckError.unknownError(
        'Failed to determine project ID. Initialize the '
        'SDK with service account credentials or set project ID as an app option. '
        'Alternatively, set the GOOGLE_CLOUD_PROJECT environment variable.',
      );
    }
  }

  AppCheckToken _toAppCheckToken(
    appcheck_v1.GoogleFirebaseAppcheckV1AppCheckToken response,
  ) {
    final token = response.token;
    if (token == null || token.isEmpty) {
      throw const FirebaseAppCheckError.invalidArgument(
        '`token` must be a valid non-empty string.',
      );
    }
    return AppCheckToken(token: token, ttl: _stringToDuration(response.ttl));
  }

  Duration _stringToDuration(String? duration) {
    if (duration == null || duration.isEmpty || !duration.endsWith('s')) {
      throw const FirebaseAppCheckError.invalidArgument(
        '`ttl` must be a valid duration string with the suffix `s`.',
      );
    }
    final seconds = double.tryParse(duration.substring(0, duration.length - 1));
    if (seconds == null) {
      throw const FirebaseAppCheckError.invalidArgument(
        '`ttl` must be a valid duration string with the suffix `s`.',
      );
    }
    return Duration(milliseconds: (seconds * 1000).floor());
  }

  FirebaseAppCheckError _fromApiError(DetailedApiRequestError error) {
    final response = error.jsonResponse;
    final apiError = response?['error'];
    if (apiError is Map) {
      return FirebaseAppCheckError.fromServerStatus(
        apiError['status'] as String?,
        apiError['message'] as String? ?? error.message,
      );
    }
    return FirebaseAppCheckError.unknownError(
      error.message ?? 'Unexpected response with status: ${error.status}',
    );
  }
}
