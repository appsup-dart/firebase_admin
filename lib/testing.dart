import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:firebase_admin/src/auth/token_verifier.dart';
import 'package:firebase_admin/src/credential.dart';
import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_admin/src/testing.dart';
import 'package:firebase_admin/src/utils/api_request.dart';
import 'package:firebase_dart/firebase_dart.dart';
import 'package:jose/jose.dart';

import 'package:firebase_dart/implementation/testing.dart';

import 'package:http/testing.dart' as http;
import 'package:http/http.dart' as http;

export 'firebase_admin.dart';

extension FirebaseAdminTestingX on FirebaseAdmin {
  Credential testCredentials() {
    return ServiceAccountMockCredential();
  }

  void setupTesting() {
    FirebaseTokenVerifier.factory = (app) => MockTokenVerifier(app);
    setApplicationDefaultCredential(testCredentials());
    _setUpMockHttpClient();
  }

  String generateMockIdToken(
      {required String projectId,
      required String uid,
      Map<String, dynamic>? overrides}) {
    overrides ??= {};

    final certificateObject =
        Credentials.applicationDefault() as ServiceAccountCredential;

    final claims = {
      'aud': projectId,
      'exp': clock.now().add(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
      'iss': 'https://securetoken.google.com/$projectId',
      'sub': uid,
      'auth_time': clock.now().millisecondsSinceEpoch ~/ 1000,
      ...overrides,
    };

    var builder = JsonWebSignatureBuilder()
      ..jsonContent = claims
      ..setProtectedHeader(
          'kid', certificateObject.certificate.privateKey.keyId)
      ..addRecipient(certificateObject.certificate.privateKey,
          algorithm: 'RS256');

    return builder.build().toCompactSerialization();
  }
}

class _BackendConnection {
  final Backend backend;
  final String projectId;

  _BackendConnection({required this.projectId})
      : backend = FirebaseTesting.getBackend(FirebaseOptions(
          projectId: projectId,
          apiKey: 'api-key-for-$projectId',
          messagingSenderId: null,
          appId: '',
        ));

  Future<Object> _handle(
      String method, String path, Map<String, dynamic> body) async {
    switch (path) {
      case 'accounts':
        switch (method) {
          case 'POST':
            var user = await backend.authBackend.createUser(
              email: body['email'],
              password: body['password'],
            );
            user.emailVerified = body['emailVerified'];
            if (body['displayName'] != null) {
              user.displayName = body['displayName'];
            }
            if (body['photoUrl'] != null) {
              user.photoUrl = body['photoUrl'];
            }
            if (body['phoneNumber'] != null) {
              user.phoneNumber = body['phoneNumber'];
            }
            if (body['disabled'] != null) {
              user.disabled = body['disabled'];
            }
            if (body['validSince'] != null) {
              user.validSince = body['validSince']?.toString();
            }
            if (body['deleteAttribute'] != null) {
              for (var attr in body['deleteAttribute']) {
                switch (attr) {
                  case 'DISPLAY_NAME':
                    user.displayName = null;
                    break;
                  case 'PHOTO_URL':
                    user.photoUrl = null;
                    break;
                  default:
                    throw Exception('Invalid deleteAttribute: $attr');
                }
              }
            }
            if (body['deleteProvider'] != null) {
              for (var provider in body['deleteProvider']) {
                switch (provider) {
                  case 'phone':
                    user.phoneNumber = null;
                    break;
                  default:
                    throw Exception('Invalid deleteProvider: $provider');
                }
              }
            }
            user = await backend.authBackend.storeUser(user);
            return user.toJson();
        }
        break;
      case 'accounts:lookup':
        switch (method) {
          case 'POST':
            var futures = <Future<BackendUser>>[];
            if (body['localId'] != null) {
              futures.addAll((body['localId'] as List)
                  .map((id) => backend.authBackend.getUserById(id)));
            }
            if (body['email'] != null) {
              futures.addAll((body['email'] as List)
                  .map((email) => backend.authBackend.getUserByEmail(email)));
            }
            if (body['phoneNumber'] != null) {
              futures.addAll((body['phoneNumber'] as List).map(
                  (phone) => backend.authBackend.getUserByPhoneNumber(phone)));
            }
            var users = await Future.wait(futures.map((v) => v
                .then<BackendUser?>((v) => v)
                .catchError((e) => null,
                    test: (e) =>
                        e is FirebaseAuthException &&
                        e.code == FirebaseAuthException.userDeleted().code)));
            users = users.whereType<BackendUser>().toList();
            return {
              'users': users.map((e) => e!.toJson()).toList(),
            };
        }
        break;
      case 'accounts:delete':
        switch (method) {
          case 'POST':
            await backend.authBackend.deleteUser(body['localId']);
            return {};
        }
        break;
      case 'accounts:update':
        switch (method) {
          case 'POST':
            var user = await backend.authBackend.getUserById(body['localId']);
            if (body['email'] != null) {
              user.email = body['email'];
            }
            if (body['displayName'] != null) {
              user.displayName = body['displayName'];
            }
            if (body['photoUrl'] != null) {
              user.photoUrl = body['photoUrl'];
            }
            if (body['phoneNumber'] != null) {
              user.phoneNumber = body['phoneNumber'];
            }
            if (body['disabled'] != null) {
              user.disabled = body['disabled'];
            }
            if (body['validSince'] != null) {
              user.validSince = body['validSince']?.toString();
            }
            if (body['deleteAttribute'] != null) {
              for (var attr in body['deleteAttribute']) {
                switch (attr) {
                  case 'DISPLAY_NAME':
                    user.displayName = null;
                    break;
                  case 'PHOTO_URL':
                    user.photoUrl = null;
                    break;
                  default:
                    throw Exception('Invalid deleteAttribute: $attr');
                }
              }
            }
            if (body['deleteProvider'] != null) {
              for (var provider in body['deleteProvider']) {
                switch (provider) {
                  case 'phone':
                    user.phoneNumber = null;
                    break;
                  default:
                    throw Exception('Invalid deleteProvider: $provider');
                }
              }
            }
            user = await backend.authBackend.updateUser(body['localId']);
            return user.toJson();
        }
        break;
      case 'accounts:sendOobCode':
        switch (method) {
          case 'POST':
            switch (body['requestType']) {
              case 'EMAIL_SIGNIN':
                try {
                  await backend.authBackend.getUserByEmail(body['email']);
                } catch (e) {
                  await backend.authBackend
                      .createUser(email: body['email'], password: null);
                }
            }

            var v = await backend.authBackend
                .createActionCode(body['requestType'], body['email']);
            return {
              'oobCode': v,
              'email': body['email'],
              if (body['returnOobLink'] == true)
                'oobLink':
                    'https://$projectId/?oobCode=$v&continueUrl=${Uri.encodeComponent(body['continueUrl'])}',
            };
        }
        break;
    }
    throw UnimplementedError('$method $path');
  }
}

void _setUpMockHttpClient() {
  AuthorizedHttpClient.httpClientFactory = () => http.MockClient((r) async {
        var path = r.url.pathSegments;

        assert(path[0] == 'v1');
        assert(path[1] == 'projects');

        var projectId = path[2];

        var connection = _BackendConnection(projectId: projectId);

        var action = path[3];
        var method = r.method;

        var body = json.decode(r.body);

        try {
          return http.Response(
              json.encode(await connection._handle(method, action, body)), 200,
              headers: {'content-type': 'application/json'}, request: r);
        } on FirebaseAuthException catch (e) {
          return http.Response(json.encode(_errorToServerResponse(e)), 400,
              headers: {'content-type': 'application/json'}, request: r);
        }
      });
}

Map<String, dynamic> _errorToServerResponse(FirebaseAuthException e) {
  return {
    'error': {
      'code': e.code,
      'message': e.message,
    }
  };
}
