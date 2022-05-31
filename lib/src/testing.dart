import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_admin/src/app.dart';
import 'package:firebase_admin/src/auth/credential.dart';
import 'package:firebase_admin/src/auth/token_verifier.dart';
import 'package:jose/jose.dart';
import 'package:openid_client/openid_client.dart' hide Credential;

class ServiceAccountMockCredential extends ServiceAccountCredential
    with MockCredentialMixin {
  @override
  // ignore: prefer_function_declarations_over_variables
  late final AccessToken Function() tokenFactory = () {
    return MockAccessToken.fromJson({
      'access_token': (JsonWebSignatureBuilder()
            ..content = JsonWebTokenClaims.fromJson(
                {'sub': 'mock-user', 'provider_id': 'testing'}).toJson()
            ..addRecipient(certificate.privateKey, algorithm: 'RS256'))
          .build()
          .toCompactSerialization(),
      'expires_in': 3600,
    });
  };
  ServiceAccountMockCredential()
      : super.fromJson({
          'type': 'service_account',
          'project_id': 'project_id',
          'private_key_id': 'aaaaaaaaaabbbbbbbbbbccccccccccdddddddddd',
          'private_key':
              '-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEAwJENcRev+eXZKvhhWLiV3Lz2MvO+naQRHo59g3vaNQnbgyduN/L4krlr\nJ5c6FiikXdtJNb/QrsAHSyJWCu8j3T9CruiwbidGAk2W0RuViTVspjHUTsIHExx9euWM0Uom\nGvYkoqXahdhPL/zViVSJt+Rt8bHLsMvpb8RquTIb9iKY3SMV2tCofNmyCSgVbghq/y7lKORt\nV/IRguWs6R22fbkb0r2MCYoNAbZ9dqnbRIFNZBC7itYtUoTEresRWcyFMh0zfAIJycWOJlVL\nDLqkY2SmIx8u7fuysCg1wcoSZoStuDq02nZEMw1dx8HGzE0hynpHlloRLByuIuOAfMCCYwID\nAQABAoIBADFtihu7TspAO0wSUTpqttzgC/nsIsNn95T2UjVLtyjiDNxPZLUrwq42tdCFur0x\nVW9Z+CK5x6DzXWvltlw8IeKKeF1ZEOBVaFzy+YFXKTz835SROcO1fgdjyrme7lRSShGlmKW/\nGKY+baUNquoDLw5qreXaE0SgMp0jt5ktyYuVxvhLDeV4omw2u6waoGkifsGm8lYivg5l3VR7\nw2IVOvYZTt4BuSYVwOM+qjwaS1vtL7gv0SUjrj85Ja6zERRdFiITDhZw6nsvacr9/+/aut9E\naL/koSSb62g5fntQMEwoT4hRnjPnAedmorM9Rhddh2TB3ZKTBbMN1tUk3fJxOuECgYEA+z6l\neSaAcZ3qvwpntcXSpwwJ0SSmzLTH2RJNf+Ld3eBHiSvLTG53dWB7lJtF4R1KcIwf+KGcOFJv\nsnepzcZBylRvT8RrAAkV0s9OiVm1lXZyaepbLg4GGFJBPi8A6VIAj7zYknToRApdW0s1x/XX\nChewfJDckqsevTMovdbg8YkCgYEAxDYX+3mfvv/opo6HNNY3SfVunM+4vVJL+n8gWZ2w9kz3\nQ9Ub9YbRmI7iQaiVkO5xNuoG1n9bM+3Mnm84aQ1YeNT01YqeyQsipP5Wi+um0PzYTaBw9RO+\n8Gh6992OwlJiRtFk5WjalNWOxY4MU0ImnJwIfKQlUODvLmcixm68NYsCgYEAuAqI3jkk55Vd\nKvotREsX5wP7gPePM+7NYiZ1HNQL4Ab1f/bTojZdTV8Sx6YCR0fUiqMqnE+OBvfkGGBtw22S\nLesx6sWf99Ov58+x4Q0U5dpxL0Lb7d2Z+2Dtp+Z4jXFjNeeI4ae/qG/LOR/b0pE0J5F415ap\n7Mpq5v89vepUtrkCgYAjMXytu4v+q1Ikhc4UmRPDrUUQ1WVSd+9u19yKlnFGTFnRjej86hiw\nH3jPxBhHra0a53EgiilmsBGSnWpl1WH4EmJz5vBCKUAmjgQiBrueIqv9iHiaTNdjsanUyaWw\njyxXfXl2eI80QPXh02+8g1H/pzESgjK7Rg1AqnkfVH9nrwKBgQDJVxKBPTw9pigYMVt9iHrR\niCl9zQVjRMbWiPOc0J56+/5FZYm/AOGl9rfhQ9vGxXZYZiOP5FsNkwt05Y1UoAAH4B4VQwbL\nqod71qOcI0ywgZiIR87CYw40gzRfjWnN+YEEW1qfyoNLilEwJB8iB/T+ZePHGmJ4MmQ/cTn9\nxpdLXA==\n-----END RSA PRIVATE KEY-----\n',
          'client_email': 'foo@project_id.iam.gserviceaccount.com'
        });
}

class MockCredential extends Credential with MockCredentialMixin {
  @override
  final AccessToken Function() tokenFactory;

  MockCredential([this.tokenFactory = MockCredentialMixin.defaultFactory]);
}

mixin MockCredentialMixin on Credential {
  AccessToken Function() get tokenFactory;

  static AccessToken defaultFactory() => MockAccessToken.fromJson({
        'access_token': 'mock-access-token',
        'expires_in': 3600,
      });

  int _callCount = 0;

  static int getCallCount(App app) {
    return (app.internals.credential as MockCredentialMixin)._callCount;
  }

  static void resetCallCount(App app) {
    (app.internals.credential as MockCredentialMixin)._callCount = 0;
  }

  @override
  Future<AccessToken> getAccessToken() async {
    _callCount++;
    return tokenFactory();
  }
}

class MockTokenVerifier extends FirebaseTokenVerifier {
  MockTokenVerifier(App app) : super(app);

  @override
  Future<Client> getOpenIdClient() async {
    var config = <String, dynamic>{
      'issuer': 'https://securetoken.google.com/project_id',
      'jwks_uri': Uri.dataFromString(
              json.encode({
                'keys': [
                  {
                    'kty': 'RSA',
                    'n':
                        'wJENcRev-eXZKvhhWLiV3Lz2MvO-naQRHo59g3vaNQnbgyduN_L4krlrJ5c6FiikXdtJNb_QrsAHSyJWCu8j3T9CruiwbidGAk2W0RuViTVspjHUTsIHExx9euWM0UomGvYkoqXahdhPL_zViVSJt-Rt8bHLsMvpb8RquTIb9iKY3SMV2tCofNmyCSgVbghq_y7lKORtV_IRguWs6R22fbkb0r2MCYoNAbZ9dqnbRIFNZBC7itYtUoTEresRWcyFMh0zfAIJycWOJlVLDLqkY2SmIx8u7fuysCg1wcoSZoStuDq02nZEMw1dx8HGzE0hynpHlloRLByuIuOAfMCCYw',
                    'e': 'AQAB',
                    'alg': 'RS256',
                    'kid': 'aaaaaaaaaabbbbbbbbbbccccccccccdddddddddd'
                  }
                ]
              }),
              mimeType: 'application/json')
          .toString(),
      'response_types_supported': ['id_token'],
      'subject_types_supported': ['public'],
      'id_token_signing_alg_values_supported': ['RS256']
    };

    var issuer = Issuer(OpenIdProviderMetadata.fromJson(config));
    return Client(issuer, projectId);
  }
}

class MockAccessToken implements AccessToken {
  @override
  final String accessToken;

  @override
  final DateTime expirationTime;

  MockAccessToken({required this.accessToken, required Duration expiresIn})
      : expirationTime = clock.now().add(expiresIn);

  MockAccessToken.fromJson(Map<String, dynamic> json)
      : this(
            accessToken: json['access_token'],
            expiresIn: Duration(seconds: json['expires_in']));
}
