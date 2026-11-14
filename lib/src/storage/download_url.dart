import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../app.dart';
import '../utils/api_request.dart';
import '../utils/error.dart';

/// Custom metadata key used by Firebase for download tokens.
const firebaseStorageDownloadTokensKey = 'firebaseStorageDownloadTokens';

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

/// Parses comma-separated download tokens from Firebase or GCS metadata.
List<String> parseDownloadTokens(String? raw) {
  if (raw == null || raw.isEmpty) return <String>[];
  return raw
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

/// Builds a Firebase download URL for [token].
Uri firebaseDownloadUrl({
  required String bucketName,
  required String objectName,
  required String token,
}) {
  final endpoint = firebaseStorageEndpoint();
  return Uri.parse(
    '$endpoint/b/$bucketName/o/${Uri.encodeComponent(objectName)}'
    '?alt=media&token=$token',
  );
}

/// Builds download URLs for every token in Firebase metadata.
List<Uri> downloadUrlsFromFirebaseMetadata({
  required String bucketName,
  required String objectName,
  required Map<String, dynamic> metadata,
}) {
  final tokens = parseDownloadTokens(metadata['downloadTokens'] as String?);
  return [
    for (final token in tokens)
      firebaseDownloadUrl(
        bucketName: bucketName,
        objectName: objectName,
        token: token,
      ),
  ];
}

/// Builds a Firebase download URL from metadata that includes `downloadTokens`.
Uri downloadUrlFromFirebaseMetadata({
  required String bucketName,
  required String objectName,
  required Map<String, dynamic> metadata,
}) {
  final urls = downloadUrlsFromFirebaseMetadata(
    bucketName: bucketName,
    objectName: objectName,
    metadata: metadata,
  );
  if (urls.isEmpty) {
    throw FirebaseStorageError.noDownloadToken();
  }
  return urls.first;
}

/// Extracts the download token from a Firebase download [url] for this object.
String downloadTokenFromUrl({
  required Uri url,
  required String bucketName,
  required String objectName,
}) {
  final expectedPath =
      '/v0/b/$bucketName/o/${Uri.encodeComponent(objectName)}';
  if (url.path != expectedPath) {
    throw FirebaseStorageError.invalidArgument(
      'Download URL does not refer to this object.',
    );
  }
  final token = url.queryParameters['token'];
  if (token == null || token.isEmpty) {
    throw FirebaseStorageError.invalidArgument(
      'Download URL is missing a token query parameter.',
    );
  }
  return token;
}

/// Generates a UUID v4 string for use as a Firebase download token.
String generateDownloadToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
