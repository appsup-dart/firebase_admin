import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:x509/x509.dart';
import '../utils/error.dart';
import 'package:jose/jose.dart';
import '../credential.dart';
import 'package:clock/clock.dart';
import 'package:openid_client/openid_client.dart' as openid;

String _openidClientId(Map<String, dynamic> json) {
  var clientId = json['client_id'];
  if (clientId is String && clientId.isNotEmpty) return clientId;
  var email = json['client_email'];
  if (email is String && email.isNotEmpty) return email;
  return 'firebase-admin';
}

/// Contains the properties necessary to use service-account JSON credentials.
class Certificate {
  final String? projectId;
  final JsonWebKey privateKey;
  final String clientEmail;

  Certificate(
      {this.projectId, required this.privateKey, required this.clientEmail});

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
    var privateKeyPem = json['private_key'];
    if (privateKeyPem is! String || privateKeyPem.isEmpty) {
      throw FirebaseAppError.invalidCredential(
        'Service account object must contain a string "private_key" property.',
      );
    }
    var clientEmail = json['client_email'];
    if (clientEmail is! String || clientEmail.isEmpty) {
      throw FirebaseAppError.invalidCredential(
        'Service account object must contain a string "client_email" property.',
      );
    }
    var projectId = json['project_id'];
    if (projectId is! String || projectId.isEmpty) {
      throw FirebaseAppError.invalidCredential(
        'Service account object must contain a string "project_id" property.',
      );
    }

    var v = parsePem(privateKeyPem).first;
    var keyPair = (v is PrivateKeyInfo) ? v.keyPair : (v as KeyPair);
    var pKey = keyPair.privateKey as RsaPrivateKey;
    var publicKey = keyPair.publicKey as RsaPublicKey?;

    var privateKey = JsonWebKey.rsa(
      modulus: pKey.modulus,
      exponent: publicKey?.exponent ?? BigInt.from(65537),
      privateExponent: pKey.privateExponent,
      firstPrimeFactor: pKey.firstPrimeFactor,
      secondPrimeFactor: pKey.secondPrimeFactor,
      keyId: json['private_key_id'] is String ? json['private_key_id'] : null,
      algorithm: 'RS256',
    );

    return Certificate(
        projectId: projectId, privateKey: privateKey, clientEmail: clientEmail);
  }
}

/// Implementation of Credential that uses a service account certificate.
class ServiceAccountCredential extends _OpenIdCredential
    implements FirebaseCredential {
  @override
  final Certificate certificate;

  ServiceAccountCredential.fromJson(Map<String, dynamic> json)
      : certificate = Certificate.fromJson(json),
        super(_openidClientId(json), null);

  factory ServiceAccountCredential(dynamic serviceAccountPathOrObject) {
    {
      if (serviceAccountPathOrObject is Map) {
        return ServiceAccountCredential.fromJson(
            serviceAccountPathOrObject.cast());
      }
      try {
        return ServiceAccountCredential.fromJson(
            json.decode(File(serviceAccountPathOrObject).readAsStringSync()));
      } on FirebaseException {
        rethrow;
      } catch (error) {
        // Throw a nicely formed error message if the file contents cannot be parsed
        throw FirebaseAppError.invalidCredential(
          'Failed to parse certificate key file: $error',
        );
      }
    }
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

  @override
  Future<openid.Credential> createCredential(openid.Client client) async {
    var flow = openid.Flow.jwtBearer(client);
    return await flow.callback({'jwt': _createAuthJwt(), 'state': flow.state});
  }
}

abstract class _OpenIdCredential implements Credential {
  final String clientId;
  final String? clientSecret;

  _OpenIdCredential(this.clientId, this.clientSecret);

  Future<openid.Credential> createCredential(openid.Client client);

  @override
  Future<AccessToken> getAccessToken() async {
    var issuer = await openid.Issuer.discover(openid.Issuer.google);
    var client = openid.Client(issuer, clientId, clientSecret: clientSecret);
    var response = await (await createCredential(client)).getTokenResponse();
    return _OpenIdAccessToken(openid.TokenResponse.fromJson({
      ...response.toJson(),
      'access_token': response.accessToken?.replaceAll(RegExp(r'\.*$'), '')
    }));
  }
}

class _OpenIdAccessToken implements AccessToken {
  final openid.TokenResponse _token;

  _OpenIdAccessToken(this._token);

  @override
  String get accessToken => _token.accessToken!;

  @override
  DateTime get expirationTime => _token.expiresAt!;
}

/// Internal interface for credentials that can both generate access tokens and
/// may have a Certificate associated with them.
abstract class FirebaseCredential implements Credential {
  Certificate get certificate;
}

/// Implementation of Credential that gets access tokens from refresh tokens.
class RefreshTokenCredential extends _OpenIdCredential {
  final String refreshToken;

  RefreshTokenCredential(Map<String, dynamic> json)
      : refreshToken = json['refresh_token'],
        super(json['client_id'], json['client_secret']);

  @override
  Future<openid.Credential> createCredential(openid.Client client) async {
    return client.createCredential(refreshToken: refreshToken);
  }
}
