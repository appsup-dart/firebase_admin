import 'dart:io';

import 'package:clock/clock.dart';
import 'package:firebase_admin/src/auth/credential.dart';
import 'package:firebase_admin/src/testing.dart';
import 'package:firebase_admin/src/utils/env.dart';
import 'package:test/test.dart';

import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_admin/src/service.dart';
import 'dart:async';
import 'resources/mocks.dart' as mocks;
import 'package:fake_async/fake_async.dart';

import 'package:firebase_admin/src/app.dart';

Matcher throwsAppError([String? message]) =>
    throwsA(TypeMatcher<FirebaseAppError>()
        .having((e) => e.message, 'message', message));

FirebaseService mockServiceFactory(App app,
    [void Function(Map props)? extendApp]) {
  return MockService(app);
}

class MockService extends FirebaseService {
  final String name;

  @override
  final App app;

  MockService(this.app) : name = app.name;

  static final List<String> calls = [];
  @override
  Future<void> delete() async {
    calls.add(name);
  }
}

void main() {
  var admin = FirebaseAdmin.instance;

  group('App', () {
    late App mockApp;

    setUp(() {
      mockApp = admin.initializeApp(mocks.appOptions, mocks.appName);
    });

    tearDown(() async {
      env
        ..clear()
        ..addAll(Platform.environment);
      for (var a in admin.apps) {
        await a.delete();
      }
    });

    group('App.name', () {
      test('should throw if the app has already been deleted', () async {
        await mockApp.delete();
        expect(
            () => mockApp.name,
            throwsAppError(
                'Firebase app named "${mocks.appName}" has already been deleted.'));
      });

      test('should return the app\'s name', () {
        expect(mockApp.name, mocks.appName);
      });

      test('should be case sensitive', () {
        var newMockAppName = mocks.appName.toUpperCase();
        mockApp = admin.initializeApp(mocks.appOptions, newMockAppName);
        expect(mockApp.name, isNot(mocks.appName));
        expect(mockApp.name, newMockAppName);
      });

      test('should respect leading and trailing whitespace', () {
        var newMockAppName = '  ${mocks.appName}  ';
        mockApp = admin.initializeApp(mocks.appOptions, newMockAppName);
        expect(mockApp.name, isNot(mocks.appName));
        expect(mockApp.name, newMockAppName);
      });
    });

    group('App.options', () {
      test('should throw if the app has already been deleted', () async {
        await mockApp.delete();

        expect(() {
          return mockApp.options;
        },
            throwsAppError(
                'Firebase app named "${mocks.appName}" has already been deleted.'));
      });

      test('should return the app\'s options', () {
        expect(mockApp.options, mocks.appOptions);
      });

      test('should ignore the config file when options is not null', () {
        env.map[FirebaseAdmin.firebaseConfigVar] =
            './test/resources/firebase_config.json';
        var app = admin.initializeApp(mocks.appOptionsNoDatabaseUrl);
        expect(app.options.databaseUrl, null);
        expect(app.options.projectId, null);
        expect(app.options.storageBucket, null);
      });

      test(
          'should throw when the environment variable points to non existing file',
          () {
        env.map[FirebaseAdmin.firebaseConfigVar] =
            './test/resources/non_existant.json';
        expect(() {
          admin.initializeApp();
        },
            throwsAppError(
                'Failed to parse app options file: FileSystemException: '
                "Cannot open file, path = './test/resources/non_existant.json' (OS Error: No such file or directory, errno = 2)"));
      });

      test('should throw when the environment variable contains bad json', () {
        env.map[FirebaseAdmin.firebaseConfigVar] = '{,,';
        expect(() {
          admin.initializeApp();
        },
            throwsAppError(
                'Failed to parse app options file: FormatException: Unexpected character (at character 2)\n{,,\n ^\n'));
      });

      test('should throw when the environment variable points to an empty file',
          () {
        env.map[FirebaseAdmin.firebaseConfigVar] =
            './test/resources/firebase_config_empty.json';
        expect(() {
          admin.initializeApp();
        },
            throwsAppError(
                'Failed to parse app options file: FormatException: Unexpected end of input (at character 1)\n\n^\n'));
      });

      test('should throw when the environment variable points to bad json', () {
        env.map[FirebaseAdmin.firebaseConfigVar] =
            './test/resources/firebase_config_bad.json';
        expect(() {
          admin.initializeApp();
        },
            throwsAppError(
                'Failed to parse app options file: FormatException: Unexpected character (at character 1)\nbaaaaad\n^\n'));
      });

      test('should ignore a bad config key in the config file', () {
        env.map[FirebaseAdmin.firebaseConfigVar] =
            './test/resources/firebase_config_bad_key.json';
        var app = admin.initializeApp();
        expect(app.options.projectId, 'hipster-chat-mock');
        expect(app.options.databaseUrl, null);
        expect(app.options.storageBucket, null);
      });

      test('should ignore a bad config key in the json string', () {
        env.map[FirebaseAdmin.firebaseConfigVar] = '{'
            '"notAValidKeyValue": "The key value here is not valid.",'
            '"projectId": "hipster-chat-mock"'
            '}';
        var app = admin.initializeApp();
        expect(app.options.projectId, 'hipster-chat-mock');
        expect(app.options.databaseUrl, null);
        expect(app.options.storageBucket, null);
      });

      test(
          'should not throw when the config file has a bad key and the config file is unused',
          () {
        env.map[FirebaseAdmin.firebaseConfigVar] =
            './test/resources/firebase_config_bad_key.json';
        var app = admin.initializeApp(mocks.appOptionsWithOverride);
        expect(app.options.projectId, 'project_id');
        expect(app.options.databaseUrl, 'https://databaseName.firebaseio.com');
        expect(app.options.storageBucket, 'bucketName.appspot.com');
      });

      test(
          'should not throw when the config json has a bad key and the config json is unused',
          () {
        env.map[FirebaseAdmin.firebaseConfigVar] = '{'
            '"notAValidKeyValue": "The key value here is not valid.",'
            '"projectId": "hipster-chat-mock"'
            '}';
        var app = admin.initializeApp(mocks.appOptionsWithOverride);
        expect(app.options.projectId, 'project_id');
        expect(app.options.databaseUrl, 'https://databaseName.firebaseio.com');
        expect(app.options.storageBucket, 'bucketName.appspot.com');
      });

      test(
          'should use explicitly specified options when available and ignore the config file',
          () {
        env.map[FirebaseAdmin.firebaseConfigVar] =
            './test/resources/firebase_config.json';
        var app = admin.initializeApp(mocks.appOptions);
        expect(app.options.credential, TypeMatcher<ServiceAccountCredential>());
        expect(app.options.databaseUrl, 'https://databaseName.firebaseio.com');
        expect(app.options.projectId, null);
        expect(app.options.storageBucket, 'bucketName.appspot.com');
      });

      test('should not throw if some fields are missing', () {
        env.map[FirebaseAdmin.firebaseConfigVar] =
            './test/resources/firebase_config_partial.json';
        var app = admin.initializeApp(mocks.appOptionsAuthDB);
        expect(app.options.databaseUrl, 'https://databaseName.firebaseio.com');
        expect(app.options.projectId, null);
        expect(app.options.storageBucket, null);
      });

      test(
          'should not throw when the config environment variable is not set, and some options are present',
          () {
        var app = admin.initializeApp(mocks.appOptionsNoDatabaseUrl);
        expect(app.options.credential, TypeMatcher<ServiceAccountCredential>());
        expect(app.options.databaseUrl, null);
        expect(app.options.projectId, null);
        expect(app.options.storageBucket, null);
      });

      test(
          'should init with application default creds when no options provided and env variable is not set',
          () {
        var app = admin.initializeApp();
        expect(app.options.credential, Credentials.applicationDefault());
        expect(app.options.databaseUrl, null);
        expect(app.options.projectId, null);
        expect(app.options.storageBucket, null);
      });

      test(
          'should init with application default creds when no options provided and env variable is an empty json',
          () {
        env.map[FirebaseAdmin.firebaseConfigVar] = '{}';
        var app = admin.initializeApp();
        expect(app.options.credential, Credentials.applicationDefault());
        expect(app.options.databaseUrl, null);
        expect(app.options.projectId, null);
        expect(app.options.storageBucket, null);
      });

      test(
          'should init when no init arguments are provided and config var points to a file',
          () {
        env.map[FirebaseAdmin.firebaseConfigVar] =
            './test/resources/firebase_config.json';
        var app = admin.initializeApp();
        expect(app.options.credential, Credentials.applicationDefault());
        expect(app.options.databaseUrl, 'https://hipster-chat.firebaseio.mock');
        expect(app.options.projectId, 'hipster-chat-mock');
        expect(app.options.storageBucket, 'hipster-chat.appspot.mock');
      });

      test(
          'should init when no init arguments are provided and config var is json',
          () {
        env.map[FirebaseAdmin.firebaseConfigVar] = '{'
            '"databaseAuthVariableOverride":  { "some#key": "some#val" },'
            '"databaseURL": "https://hipster-chat.firebaseio.mock",'
            '"projectId": "hipster-chat-mock",'
            '"storageBucket": "hipster-chat.appspot.mock"'
            '}';

        var app = admin.initializeApp();
        expect(app.options.credential, Credentials.applicationDefault());
        expect(app.options.databaseUrl, 'https://hipster-chat.firebaseio.mock');
        expect(app.options.projectId, 'hipster-chat-mock');
        expect(app.options.storageBucket, 'hipster-chat.appspot.mock');
      });
    });

    group('App.delete()', () {
      test('should throw if the app has already been deleted', () async {
        await mockApp.delete();
        expect(() {
          return mockApp.delete();
        },
            throwsAppError(
                'Firebase app named "${mocks.appName}" has already been deleted.'));
      });

      test('should call removeApp() on the Firebase namespace internals',
          () async {
        await mockApp.delete();
        expect(
            () => admin.app(mocks.appName),
            throwsAppError(
                'Firebase app named "mock-app-name" does not exist. Make sure you call initializeApp() before using any of the Firebase services.'));
      });
    });

    group('App.auth()', () {
      test('should throw if the app has already been deleted', () async {
        var app = mockApp;

        await app.delete();
        expect(
            () => app.auth(),
            throwsAppError(
                'Firebase app named "${mocks.appName}" has already been deleted.'));
      });

      test('should return the Auth namespace', () {
        var app = mockApp;

        var auth = app.auth();

        expect(auth, isNotNull);
      });

      test('should return a cached version of Auth on subsequent calls', () {
        var app = mockApp;
        var auth1 = app.auth();
        var auth2 = app.auth();
        expect(auth1, auth2);
      });
    });

    group('App.internals.getToken()', () {
      setUpAll(() {});

      tearDownAll(() {});

      test(
          'returns a valid token given a well-formed custom credential implementation',
          () async {
        var oracle = MockAccessToken(
            accessToken: 'This is a custom token',
            expiresIn: Duration(hours: 1));
        var credential = MockCredential(() => oracle);

        var app = admin.initializeApp(AppOptions(credential: credential));

        var token = await app.internals.getToken();
        expect(token.accessToken, oracle.accessToken);
        expect(token.expirationTime, oracle.expirationTime);
      });

      test('returns a valid token given no arguments', () async {
        var token = await mockApp.internals.getToken();
        expect(token.accessToken, allOf(isNotNull, isNotEmpty));
        expect(token.expirationTime, isNotNull);
      });
      test('returns a valid token with force refresh', () async {
        var token = await mockApp.internals.getToken(true);
        expect(token.accessToken, allOf(isNotNull, isNotEmpty));
        expect(token.expirationTime, isNotNull);
      });
      test('returns the cached token given no arguments', () async {
        var token1 = await mockApp.internals.getToken(true);
        await Future.delayed(Duration(seconds: 1));
        var token2 = await mockApp.internals.getToken();
        expect(token1, token2);
      });
      test('returns a token with force refresh', () async {
        var token1 = await mockApp.internals.getToken(true);
        await Future.delayed(Duration(seconds: 1));
        var token2 = await mockApp.internals.getToken(true);
        expect(token1, isNot(token2));
      });

      test('proactively refreshes the token five minutes setUp it expires', () {
        testFakeAsync((fake) async {
          // Force a token refresh.
          var token1 = await mockApp.internals.getToken(true);
          var expiryIn = token1.expirationTime.difference(clock.now());
          // Forward the clock to five minutes and one second setUp expiry.
          fake.elapse(expiryIn - Duration(minutes: 5, seconds: 1));

          var token2 = await mockApp.internals.getToken();
          // Ensure the token has not been proactively refreshed.
          expect(token2, token1);
          // Forward the clock to exactly five minutes setUp expiry.
          fake.elapse(Duration(seconds: 1));

          var token3 = await mockApp.internals.getToken();
          expect(token3, isNot(token1));
        });
      });

      test(
          'retries to proactively refresh the token if a proactive refresh attempt fails',
          () {
        return testFakeAsync((fake) async {
          var reject = false;

          await admin.app(mocks.appName)!.delete();
          var mockApp =
              admin.initializeApp(AppOptions(credential: MockCredential(() {
            if (reject) throw Exception('Intentionally rejected');
            return MockAccessToken(
                accessToken: 'key', expiresIn: Duration(hours: 1));
          })), mocks.appName);
          // Force a token refresh.
          var token1 = await mockApp.internals.getToken(true);
          // Stub the getToken() method to return a rejected promise.
          reject = true;
          // Forward the clock to exactly five minutes setUp expiry.
          var expiryIn = token1.expirationTime.difference(clock.now());
          fake.elapse(expiryIn - Duration(minutes: 5));
          // Forward the clock to exactly four minutes setUp expiry.
          fake.elapse(Duration(minutes: 1));

          // Restore the stubbed getAccessToken() method.
          reject = false;

          var token2 = await mockApp.internals.getToken();
          // Ensure the token has not been proactively refreshed.
          expect(token1, token2);

          // Forward the clock to exactly three minutes setUp expiry.
          fake.elapse(Duration(minutes: 1));
          var token3 = await mockApp.internals.getToken();

          // Ensure the token was proactively refreshed.
          expect(token1, isNot(token3));
        });
      });

      test(
          'stops retrying to proactively refresh the token after five attempts',
          () {
        return testFakeAsync((fake) async {
          var reject = false;
          var callCount = 0;

          await admin.app(mocks.appName)!.delete();
          var mockApp =
              admin.initializeApp(AppOptions(credential: MockCredential(() {
            callCount++;
            if (reject) throw Exception('Intentionally rejected');
            return MockAccessToken(
                accessToken: 'key', expiresIn: Duration(hours: 1));
          })), mocks.appName);

          // Force a token refresh.
          var originalToken = await mockApp.internals.getToken(true);

          // Stub the credential's getAccessToken() method to always return a rejected promise.
          reject = true;
          callCount = 0;

          // Forward the clock to exactly five minutes setUp expiry.
          var expiryIn = originalToken.expirationTime.difference(clock.now());
          fake.elapse(expiryIn - Duration(minutes: 5));

          var token = await mockApp.internals.getToken();
          // Ensure the token was attempted to be proactively refreshed one time.
          expect(callCount, 1);

          // Ensure the proactive refresh failed.
          expect(token, originalToken);
          // Forward the clock to four minutes setUp expiry.
          fake.elapse(Duration(minutes: 1));

          token = await mockApp.internals.getToken();

          // Ensure the token was attempted to be proactively refreshed two times.
          expect(callCount, 2);

          // Ensure the proactive refresh failed.
          expect(token, originalToken);

          // Forward the clock to three minutes setUp expiry.
          fake.elapse(Duration(minutes: 1));

          token = await mockApp.internals.getToken();

          // Ensure the token was attempted to be proactively refreshed three times.
          expect(callCount, 3);

          // Ensure the proactive refresh failed.
          expect(token, originalToken);

          // Forward the clock to two minutes setUp expiry.
          fake.elapse(Duration(minutes: 1));

          token = await mockApp.internals.getToken();

          // Ensure the token was attempted to be proactively refreshed four times.
          expect(callCount, 4);

          // Ensure the proactive refresh failed.
          expect(token, originalToken);

          // Forward the clock to one minute setUp expiry.
          fake.elapse(Duration(minutes: 1));

          token = await mockApp.internals.getToken();

          // Ensure the token was attempted to be proactively refreshed five times.
          expect(callCount, 5);

          // Ensure the proactive refresh failed.
          expect(token, originalToken);

          // Forward the clock to expiry.
          fake.elapse(Duration(minutes: 1));

          token = await mockApp.internals.getToken();

          // Ensure the token was not attempted to be proactively refreshed a sixth time.
          expect(callCount, 5);

          // Ensure the token has never been refresh.
          expect(token, originalToken);
        });
      });

      test('resets the proactive refresh timeout upon a force refresh', () {
        testFakeAsync((fake) async {
          // Force a token refresh.
          var token1 = await mockApp.internals.getToken(true);
          // Forward the clock to five minutes and one second setUp expiry.
          var expiryInMilliseconds =
              token1.expirationTime.difference(clock.now());
          fake.elapse(expiryInMilliseconds - Duration(minutes: 5, seconds: 1));

          // Force a token refresh.
          var token2 = await mockApp.internals.getToken(true);
          // Ensure the token was force refreshed.
          expect(token1, isNot(token2));

          // Forward the clock to exactly five minutes setUp the original token's expiry.
          fake.elapse(Duration(seconds: 1));
          var token3 = await mockApp.internals.getToken();
          // Ensure the token hasn't changed, meaning the proactive refresh was canceled.
          expect(token2, token3);

          // Forward the clock to exactly five minutes setUp the refreshed token's expiry.
          expiryInMilliseconds = token3.expirationTime.difference(clock.now());
          fake.elapse(expiryInMilliseconds - Duration(minutes: 5));

          var token4 = await mockApp.internals.getToken();
          // Ensure the token was proactively refreshed.
          expect(token3, isNot(token4));
        });
      });

      test(
          'proactively refreshes the token at the next full minute if it expires in five minutes or less',
          () {
        testFakeAsync((fake) async {
          await admin.app(mocks.appName)!.delete();
          var mockApp =
              admin.initializeApp(AppOptions(credential: MockCredential(() {
            return MockAccessToken(
                accessToken: 'key',
                expiresIn: Duration(minutes: 3, seconds: 10));
          })), mocks.appName);

          // Force a token refresh.
          var token1 = await mockApp.internals.getToken(true);

          MockCredentialMixin.resetCallCount(mockApp);

          // Move the clock forward to three minutes and one second setUp expiry.
          fake.elapse(Duration(seconds: 9));

          // Expect the call count to initially be zero.
          expect(MockCredentialMixin.getCallCount(mockApp), 0);

          // Move the clock forward to exactly three minutes setUp expiry.
          fake.elapse(Duration(seconds: 1));

          // Expect the underlying getAccessToken() method to have been called once.
          expect(MockCredentialMixin.getCallCount(mockApp), 1);

          var token2 = await mockApp.internals.getToken();
          // Ensure the token was proactively refreshed.
          expect(token1, isNot(token2));
        });
      });
    });

    group('App.internals.addAuthTokenListener()', () {
      test('is notified when the token changes', () async {
        String? calledWithValue;
        mockApp.internals.addAuthTokenListener(expectAsync1((v) {
          calledWithValue = v;
        }, count: 1));

        var token = await mockApp.internals.getToken();
        expect(calledWithValue, token.accessToken);
      });
      test('can be called twice', () async {
        var values = [];
        var listener = expectAsync1((v) => values.add(v), count: 2);
        mockApp.internals.addAuthTokenListener(listener);
        mockApp.internals.addAuthTokenListener(listener);

        var token = await mockApp.internals.getToken();

        expect(values, [token.accessToken, token.accessToken]);
      });
      test('will be called on token refresh', () {
        testFakeAsync((fake) async {
          var values = [];
          var listener = expectAsync1((v) => values.add(v), count: 2);
          mockApp.internals.addAuthTokenListener(listener);

          var token1 = await mockApp.internals.getToken();

          fake.elapse(Duration(seconds: 1));

          var token2 = await mockApp.internals.getToken(true);

          expect(values, [token1.accessToken, token2.accessToken]);
        });
      });
      test('will fire with the initial token if it exists', () async {
        var getTokenResult = await mockApp.internals.getToken();
        var completer = Completer();
        mockApp.internals.addAuthTokenListener((token) {
          completer.complete(token);
        });

        var addAuthTokenListenerArgument = await completer.future;
        expect(addAuthTokenListenerArgument, getTokenResult.accessToken);
      });
    });

    group('App.internals.removeTokenListener()', () {
      test('removes the listener', () {
        testFakeAsync((fake) async {
          var values = [];
          var listener1 = expectAsync1((v) => values.add(v), count: 1);
          var listener2 = expectAsync1((v) => values.add(v), count: 2);
          mockApp.internals.addAuthTokenListener(listener1);
          mockApp.internals.addAuthTokenListener(listener2);

          var token1 = await mockApp.internals.getToken();

          mockApp.internals.removeAuthTokenListener(listener1);

          fake.elapse(Duration(seconds: 1));

          var token2 = await mockApp.internals.getToken(true);

          expect(values,
              [token1.accessToken, token1.accessToken, token2.accessToken]);
        });
      });
    });
  });
}

void testFakeAsync(Function(FakeAsync) body) {
  fakeAsync((fake) {
    Future.value()
        .then((_) => body(fake))
        .then(expectAsync1((_) => null, count: 1));
    fake.flushMicrotasks();
  });
}
