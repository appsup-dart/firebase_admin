import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';

import 'auth/credential.dart';
import 'utils/error.dart';
import 'package:path/path.dart' as path;

class Credentials {
  static Credential _globalAppDefaultCred;

  /// Returns a [Credential] created from the Google Application Default
  /// Credentials (ADC) that grants admin access to Firebase services.
  ///
  /// This credential can be used in the call to [initializeApp].
  static Credential applicationDefault() =>
      _globalAppDefaultCred ??= _getApplicationDefault();

  /// Returns [Credential] created from the provided service account that grants
  /// admin access to Firebase services.
  ///
  /// This credential can be used in the call to [initializeApp].
  /// [credentials] must be a path to a service account key JSON file or an
  /// object representing a service account key.
  static Credential cert(credentials) {
    throw UnimplementedError();
  }

  /// Returns [Credential] created from the provided refresh token that grants
  /// admin access to Firebase services.
  ///
  /// This credential can be used in the call to [initializeApp].
  static Credential refreshToken(refreshTokenPathOrObject) {
    throw UnimplementedError();
  }

  static String get _gcloudCredentialPath {
    var config = _configDir;
    if (config == null) return null;
    return path.join(config, 'gcloud/application_default_credentials.json');
  }

  static String get _configDir {
    // Windows has a dedicated low-rights location for apps at ~/Application Data
    if (Platform.isWindows) {
      return env['APPDATA'];
    }

    // On *nix the gcloud cli creates a . dir.
    if (env.containsKey('HOME')) {
      return path.join(env['HOME'], '.config');
    }
    return null;
  }

  static Credential _getApplicationDefault() {
    if (env['GOOGLE_APPLICATION_CREDENTIALS'] != null) {
      return _credentialFromFile(env['GOOGLE_APPLICATION_CREDENTIALS']);
    }

    // It is OK to not have this file. If it is present, it must be valid.
    if (_gcloudCredentialPath != null) {
      final refreshToken = _readCredentialFile(_gcloudCredentialPath, true);
      if (refreshToken != null) {
        return RefreshTokenCredential(refreshToken);
      }
    }

    throw UnsupportedError('Credential on compute engine not supported');
  }

  static Credential _credentialFromFile(String filePath) {
    final credentialsFile = _readCredentialFile(filePath);
    if (credentialsFile == null) {
      throw FirebaseAppError.invalidCredential(
        'Failed to parse contents of the credentials file as an object',
      );
    }

    if (credentialsFile['type'] == 'service_account') {
      return ServiceAccountCredential(credentialsFile);
    }

    if (credentialsFile['type'] == 'authorized_user') {
      return RefreshTokenCredential(credentialsFile);
    }

    throw FirebaseAppError.invalidCredential(
      'Invalid contents in the credentials file',
    );
  }

  static Map<String, dynamic> _readCredentialFile(String filePath,
      [bool ignoreMissing = false]) {
    String fileText;
    try {
      fileText = File(filePath).readAsStringSync();
    } catch (error) {
      if (ignoreMissing) {
        return null;
      }

      throw FirebaseAppError.invalidCredential(
          'Failed to read credentials from file ${filePath}: $error');
    }

    try {
      return json.decode(fileText);
    } catch (error) {
      throw FirebaseAppError.invalidCredential(
          'Failed to parse contents of the credentials file as an object: $error');
    }
  }
}

/// Interface which provides Google OAuth2 access tokens used to authenticate
/// with Firebase services.
abstract class Credential {
  /// Returns a Google OAuth2 [AccessToken] object used to authenticate with
  /// Firebase services.
  Future<AccessToken> getAccessToken();
}

/// Google OAuth2 access token object used to authenticate with Firebase
/// services.
abstract class AccessToken {
  /// The actual Google OAuth2 access token.
  String get accessToken;

  DateTime get expirationTime;
}
