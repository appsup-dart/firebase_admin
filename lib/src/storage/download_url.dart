import 'dart:convert';
import 'dart:io';

import '../app.dart';
import '../utils/api_request.dart';
import '../utils/error.dart';

/// Firebase Storage HTTP API base (`…/v0`), honoring `STORAGE_EMULATOR_HOST`.
String firebaseStorageEndpoint() {
  final emulator = Platform.environment['STORAGE_EMULATOR_HOST'];
  if (emulator != null && emulator.isNotEmpty) {
    final host = emulator.startsWith('http') ? emulator : 'http://$emulator';
    return '$host/v0';
  }
  return 'https://firebasestorage.googleapis.com/v0';
}

/// Fetches Firebase object metadata (including download tokens) for [objectName].
Future<Map<String, dynamic>> getFirebaseStorageMetadata({
  required App app,
  required String bucketName,
  required String objectName,
}) async {
  final endpoint = firebaseStorageEndpoint();
  final uri = Uri.parse(
    '$endpoint/b/$bucketName/o/${Uri.encodeComponent(objectName)}',
  );
  final client = AuthorizedHttpClient(app, const Duration(seconds: 25));
  try {
    final response = await client.get(uri);
    if (response.statusCode >= 400) {
      throw FirebaseStorageError(
        'unknown-error',
        'Failed to get Firebase Storage metadata '
            '(status: ${response.statusCode}): ${response.body}',
      );
    }
    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw FirebaseStorageError(
        'unknown-error',
        'Unexpected Firebase Storage metadata response.',
      );
    }
    return decoded;
  } finally {
    client.close();
  }
}

/// Builds a Firebase download URL from metadata that includes `downloadTokens`.
Uri downloadUrlFromFirebaseMetadata({
  required String bucketName,
  required String objectName,
  required Map<String, dynamic> metadata,
}) {
  final tokens = metadata['downloadTokens'];
  if (tokens is! String || tokens.isEmpty) {
    throw FirebaseStorageError.noDownloadToken();
  }
  final token = tokens.split(',').first.trim();
  if (token.isEmpty) {
    throw FirebaseStorageError.noDownloadToken();
  }
  final endpoint = firebaseStorageEndpoint();
  return Uri.parse(
    '$endpoint/b/$bucketName/o/${Uri.encodeComponent(objectName)}'
    '?alt=media&token=$token',
  );
}
