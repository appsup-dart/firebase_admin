import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:x509/x509.dart';
import '../utils/error.dart';
import 'package:http/http.dart' as http;
import 'package:jose/jose.dart';
import 'package:crypto_keys/crypto_keys.dart';
import 'package:meta/meta.dart';
import '../credential.dart';
import 'package:clock/clock.dart';

/// Contains the properties necessary to use service-account JSON credentials.
class Certificate {
  final String projectId;
  final JsonWebKey privateKey;
  final String clientEmail;

  Certificate({this.projectId, this.privateKey, this.clientEmail}) {
    if (privateKey == null) {
      throw FirebaseAppError.invalidCredential(
          'Certificate object must contain a string "private_key" property.');
    } else if (clientEmail == null) {
      throw FirebaseAppError.invalidCredential(
          'Certificate object must contain a string "client_email" property.');
    }
  }

  factory Certificate.fromPath(String filePath) {
    try {
      return Certificate.fromJson(
          json.decode(File(filePath).readAsStringSync()));
    } on FirebaseException {
      rethrow;
    } catch (error) {
      // Throw a nicely formed error message if the file contents cannot be parsed
      throw FirebaseAppError.invalidCredential(
        'Failed to parse certificate key file: $error',
      );
    }
  }

  factory Certificate.fromJson(Map<String, dynamic> json) {
    if (json == null) {
      throw FirebaseAppError.invalidCredential(
        'Certificate object must be an object.',
      );
    }

    var privateKey = json['private_key'];
    if (privateKey is! String) privateKey = null;
    var clientEmail = json['client_email'];
    if (clientEmail is! String) clientEmail = null;

    var v = parsePem(privateKey).first;
    var keyPair = (v is PrivateKeyInfo) ? v.keyPair : v as KeyPair;
    var pKey = keyPair.privateKey as RsaPrivateKey;

    String _bytesToBase64(List<int> bytes) {
      return base64Url.encode(bytes).replaceAll('=', '');
    }

    String _intToBase64(BigInt v) {
      return _bytesToBase64(v
          .toRadixString(16)
          .replaceAllMapped(RegExp('[0-9a-f]{2}'), (m) => '${m.group(0)},')
          .split(',')
          .where((v) => v.isNotEmpty)
          .map((v) => int.parse(v, radix: 16))
          .toList());
    }

    var k = JsonWebKey.fromJson({
      'kty': 'RSA',
      'n': _intToBase64(pKey.modulus),
      'd': _intToBase64(pKey.privateExponent),
      'p': _intToBase64(pKey.firstPrimeFactor),
      'q': _intToBase64(pKey.secondPrimeFactor),
      'alg': 'RS256',
      'kid': json['private_key_id']
    });

    return Certificate(
        projectId: json['project_id'], privateKey: k, clientEmail: clientEmail);
  }
}

/// Implementation of Credential that uses a service account certificate.
class ServiceAccountCredential implements FirebaseCredential {
  @override
  final Certificate certificate;
  final http.Client httpClient = http.Client();

  ServiceAccountCredential(serviceAccountPathOrObject)
      : certificate = serviceAccountPathOrObject is String
            ? Certificate.fromPath(serviceAccountPathOrObject)
            : Certificate.fromJson(
                serviceAccountPathOrObject); // TODO two distinct constructors

  @override
  Future<AccessToken> getAccessToken() async {
    final token = _createAuthJwt();
    final postData = 'grant_type=urn%3Aietf%3Aparams%3Aoauth%3A'
        'grant-type%3Ajwt-bearer&assertion=$token';
    final request = http.Request(
        'POST', Uri.parse('https://accounts.google.com/o/oauth2/token'))
      ..headers.addAll({
        'Content-Type': 'application/x-www-form-urlencoded',
      })
      ..body = postData;

    return _requestAccessToken(httpClient, request);
  }

  /// Obtain a OAuth2 token by making a remote service call.
  Future<FirebaseAccessToken> _requestAccessToken(
      http.Client client, http.Request request) async {
    var resp = await http.Response.fromStream(await client.send(request));

    var data = json.decode(resp.body);
    if (resp.statusCode < 300) {
      var token = FirebaseAccessToken.fromJson(data);
      if (token.expirationTime == null || token.accessToken == null) {
        throw FirebaseAppError.invalidCredential(
          'Unexpected response while fetching access token: ${json.encode(data)}',
        );
      }
      return token;
    }
    throw FirebaseAppError.invalidCredential(
      'Invalid access token generated: "${json.encode(data)}". Valid access '
      'tokens must be an object with the "expires_in" (number) and "access_token" '
      '(string) properties.',
    );
  }

  String _createAuthJwt() {
    final claims = {
      'scope': [
        'https://www.googleapis.com/auth/cloud-platform',
        'https://www.googleapis.com/auth/firebase.database',
        'https://www.googleapis.com/auth/firebase.messaging',
        'https://www.googleapis.com/auth/identitytoolkit',
        'https://www.googleapis.com/auth/userinfo.email',
      ].join(' '),
      'aud': 'https://accounts.google.com/o/oauth2/token',
      'iss': certificate.clientEmail,
      'iat': clock.now().millisecondsSinceEpoch ~/ 1000,
      'exp': clock.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000
    };

    var builder = JsonWebSignatureBuilder()
      ..jsonContent = claims
      ..addRecipient(certificate.privateKey, algorithm: 'RS256');

    return builder.build().toCompactSerialization();
  }
}

/// Internal interface for credentials that can both generate access tokens and
/// may have a Certificate associated with them.
abstract class FirebaseCredential implements Credential {
  Certificate get certificate;
}

class FirebaseAccessToken implements AccessToken {
  @override
  final String accessToken;

  @override
  final DateTime expirationTime;

  FirebaseAccessToken.fromJson(Map<String, dynamic> json)
      : this(
            accessToken: json['access_token'],
            expiresIn: Duration(seconds: json['expires_in']));

  FirebaseAccessToken(
      {@required this.accessToken, @required Duration expiresIn})
      : expirationTime = expiresIn == null ? null : clock.now().add(expiresIn);

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'expirationTime': expirationTime?.toIso8601String()
      };
}

/// Implementation of Credential that gets access tokens from refresh tokens.
class RefreshTokenCredential implements Credential {
  RefreshTokenCredential(refreshTokenPathOrObject);
  @override
  Future<AccessToken> getAccessToken() {
    throw UnimplementedError();
  }
}
