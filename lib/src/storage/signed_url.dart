import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';

import '../app.dart';
import '../auth/credential.dart';
import '../utils/error.dart';

/// Action authorized by a [File.getSignedUrl] / [Bucket.getSignedUrl].
enum SignedUrlAction {
  /// HTTP GET — download object content.
  read,

  /// HTTP PUT — upload/replace object content.
  write,

  /// HTTP DELETE — delete the object.
  delete,

  /// HTTP POST with `x-goog-resumable: start` — start a resumable upload.
  resumable,
}

extension on SignedUrlAction {
  String get httpMethod => switch (this) {
    SignedUrlAction.read => 'GET',
    SignedUrlAction.write => 'PUT',
    SignedUrlAction.delete => 'DELETE',
    SignedUrlAction.resumable => 'POST',
  };
}

/// Creates a V4 signed URL for [objectName] in [bucketName].
///
/// Requires the app to be initialized with a [ServiceAccountCredential] that
/// includes a private key. Maximum [expires] is 7 days.
Uri createSignedUrl({
  required App app,
  required String bucketName,
  required String objectName,
  required SignedUrlAction action,
  required Duration expires,
  String? contentType,
  Map<String, String>? headers,
  Map<String, String>? queryParams,
}) {
  final expiresSeconds = expires.inSeconds;
  if (expiresSeconds <= 0) {
    throw FirebaseStorageError.invalidArgument(
      'expires must be a positive duration.',
    );
  }
  if (expiresSeconds > 604800) {
    throw FirebaseStorageError.invalidArgument(
      'expires cannot be longer than 7 days (604800 seconds).',
    );
  }

  final certificate = _signingCertificate(app);
  final now = clock.now().toUtc();
  final requestTimestamp = _formatGoogDate(now);
  final datestamp = _formatGoogDatestamp(now);
  final credentialScope = '$datestamp/auto/storage/goog4_request';
  final credential = '${certificate.clientEmail}/$credentialScope';

  final host = '$bucketName.storage.googleapis.com';
  final headerMap = <String, String>{
    ...?headers,
    if (contentType != null) 'content-type': contentType,
    if (action == SignedUrlAction.resumable) 'x-goog-resumable': 'start',
    'host': host,
  };

  // Canonical headers: sorted by lowercased name; values trimmed + lowercased.
  final sortedHeaderKeys = headerMap.keys.map((k) => k.toLowerCase()).toList()
    ..sort();
  final normalizedHeaders = <String, String>{};
  for (final key in sortedHeaderKeys) {
    // Match the original map case-insensitively.
    final value = headerMap.entries
        .firstWhere((e) => e.key.toLowerCase() == key)
        .value;
    normalizedHeaders[key] = value.trim().toLowerCase();
  }
  final canonicalHeaders = normalizedHeaders.entries
      .map((e) => '${e.key}:${e.value}\n')
      .join();
  final signedHeaders = normalizedHeaders.keys.join(';');

  final query = <String, String>{
    ...?queryParams,
    'X-Goog-Algorithm': 'GOOG4-RSA-SHA256',
    'X-Goog-Credential': credential,
    'X-Goog-Date': requestTimestamp,
    'X-Goog-Expires': '$expiresSeconds',
    'X-Goog-SignedHeaders': signedHeaders,
  };

  final sortedQueryKeys = query.keys.toList()..sort();
  final canonicalQueryString = sortedQueryKeys
      .map((k) => '${_uriEncode(k)}=${_uriEncode(query[k]!)}')
      .join('&');

  final canonicalUri = _canonicalObjectPath(objectName);
  final canonicalRequest = [
    action.httpMethod,
    canonicalUri,
    canonicalQueryString,
    canonicalHeaders,
    signedHeaders,
    'UNSIGNED-PAYLOAD',
  ].join('\n');

  final canonicalRequestHash =
      sha256.convert(utf8.encode(canonicalRequest)).toString();
  final stringToSign = [
    'GOOG4-RSA-SHA256',
    requestTimestamp,
    credentialScope,
    canonicalRequestHash,
  ].join('\n');

  final signatureBytes = certificate.privateKey.sign(
    utf8.encode(stringToSign),
    algorithm: 'RS256',
  );
  final signature = _hexEncode(signatureBytes);

  return Uri.parse(
    'https://$host$canonicalUri?$canonicalQueryString&X-Goog-Signature=$signature',
  );
}

Certificate _signingCertificate(App app) {
  final credential = app.options.credential;
  if (credential is ServiceAccountCredential) {
    return credential.certificate;
  }
  throw FirebaseStorageError.invalidArgument(
    'Signed URLs require the app to be initialized with a service account '
    'credential that includes a private key.',
  );
}

/// Path with `/` separators preserved; other characters percent-encoded.
String _canonicalObjectPath(String objectName) {
  final trimmed = objectName.startsWith('/')
      ? objectName.substring(1)
      : objectName;
  final encoded = trimmed
      .split('/')
      .map((segment) => _uriEncode(segment))
      .join('/');
  return '/$encoded';
}

String _uriEncode(String value) => Uri.encodeComponent(value);

String _formatGoogDate(DateTime utc) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}'
      '${two(utc.month)}${two(utc.day)}T'
      '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

String _formatGoogDatestamp(DateTime utc) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}'
      '${two(utc.month)}${two(utc.day)}';
}

String _hexEncode(List<int> bytes) {
  final out = StringBuffer();
  for (final b in bytes) {
    out.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return out.toString();
}
