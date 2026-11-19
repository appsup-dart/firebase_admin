import 'package:firebase_admin/src/utils/api_request.dart';
import 'package:firebase_admin/src/utils/http_client.dart';
import 'package:firebase_admin/testing.dart';
// ignore: implementation_imports
import 'package:firebase_dart/src/implementation.dart';
// ignore: implementation_imports
import 'package:firebase_dart/src/implementation/dart.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'resources/mocks.dart' as mocks;

/// Stands in for the implementation that `FirebaseDart.setup` installs.
///
/// firebase_dart exposes the setup client from 2.0 on. This package is tested
/// against an older version, so the client is exposed here.
class _SetupImplementation implements PureDartFirebaseImplementation {
  _SetupImplementation(this.httpClient);

  final Client httpClient;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final setupClient = MockClient((_) async => Response('', 500));

  late Client Function() previousFactory;

  setUpAll(() {
    FirebaseImplementation.install(_SetupImplementation(setupClient));
  });

  setUp(() {
    previousFactory = AuthorizedHttpClient.httpClientFactory;
  });

  tearDown(() {
    AuthorizedHttpClient.httpClientFactory = previousFactory;
  });

  group('resolveHttpClient', () {
    test('uses the FirebaseDart.setup client when no factory is set', () {
      expect(resolveHttpClient(), same(setupClient));
    });

    test('uses a factory that was set, over the FirebaseDart.setup client', () {
      final factoryClient = MockClient((_) async => Response('', 200));
      AuthorizedHttpClient.httpClientFactory = () => factoryClient;

      expect(resolveHttpClient(), same(factoryClient));
    });

    test('uses the FirebaseDart.setup client again once the factory is restored',
        () {
      final original = AuthorizedHttpClient.httpClientFactory;
      AuthorizedHttpClient.httpClientFactory =
          () => MockClient((_) async => Response('', 200));
      AuthorizedHttpClient.httpClientFactory = original;

      expect(resolveHttpClient(), same(setupClient));
    });
  });

  group('setupTesting', () {
    test('serves Auth from the in-memory backend after FirebaseDart.setup',
        () async {
      final admin = FirebaseAdmin.instance;
      admin.setupTesting();
      final app = admin.initializeApp(mocks.appOptions, 'http-client-test');
      addTearDown(app.delete);

      final user = await app
          .auth()
          .createUser(email: 'user@example.com', password: 'secret');

      expect(user.email, 'user@example.com');
    });
  });
}
