import 'dart:convert';
import 'dart:io';

import 'package:firebase_admin/src/auth/auth_api_request.dart';
import 'package:firebase_admin/src/auth/user_record.dart';
import 'package:firebase_admin/testing.dart';
import 'package:jose/jose.dart';
import 'package:openid_client/openid_client.dart';
import 'package:test/test.dart';
import 'resources/mocks.dart' as mocks;
import 'package:mockito/mockito.dart';

import 'resources/mocks.dart';

Matcher throwsFirebaseError([String? code]) => throwsA(
    TypeMatcher<FirebaseException>().having((e) => e.code, 'code', code));

class MockAuthRequestHandler extends Mock implements AuthRequestHandler {
  @override
  Future<String> getEmailActionLink(String requestType, String email,
          {ActionCodeSettings? actionCodeSettings}) =>
      super.noSuchMethod(
          Invocation.method(#getEmailActionLink, [requestType, email],
              {#actionCodeSettings: actionCodeSettings}),
          returnValue: Future.value(''));

  @override
  Future<Map<String, dynamic>> getAccountInfoByUid(String uid) =>
      super.noSuchMethod(Invocation.method(#getAccountInfoByUid, [uid]),
          returnValue: Future.value(<String, dynamic>{}));

  @override
  Future<Map<String, dynamic>> getAccountInfoByEmail(String email) =>
      super.noSuchMethod(Invocation.method(#getAccountInfoByEmail, [email]),
          returnValue: Future.value(<String, dynamic>{}));

  @override
  Future<Map<String, dynamic>> getAccountInfoByPhoneNumber(
          String phoneNumber) =>
      super.noSuchMethod(
          Invocation.method(#getAccountInfoByPhoneNumber, [phoneNumber]),
          returnValue: Future.value(<String, dynamic>{}));

  @override
  Future<Map<String, dynamic>> downloadAccount(
          int? maxResults, String? pageToken) =>
      super.noSuchMethod(
          Invocation.method(#downloadAccount, [maxResults, pageToken]),
          returnValue: Future.value(<String, dynamic>{}));

  @override
  Future<String> createNewAccount(CreateEditAccountRequest request) =>
      super.noSuchMethod(Invocation.method(#createNewAccount, [request]),
          returnValue: Future.value(''));

  @override
  Future<Map<String, dynamic>> deleteAccount(String uid) =>
      super.noSuchMethod(Invocation.method(#deleteAccount, [uid]),
          returnValue: Future.value(<String, dynamic>{}));

  @override
  Future<String> updateExistingAccount(
          String uid, CreateEditAccountRequest request) =>
      super.noSuchMethod(
          Invocation.method(#updateExistingAccount, [uid, request]),
          returnValue: Future.value(''));

  @override
  Future<String> setCustomUserClaims(
          String uid, Map<String, dynamic>? customUserClaims) =>
      super.noSuchMethod(
          Invocation.method(#setCustomUserClaims, [uid, customUserClaims]),
          returnValue: Future.value(''));

  @override
  Future<String> revokeRefreshTokens(String uid) =>
      super.noSuchMethod(Invocation.method(#revokeRefreshTokens, [uid]),
          returnValue: Future.value(''));
}

void main() {
  var admin = FirebaseAdmin.instance;
  var mockRequestHandler = MockAuthRequestHandler();
  group('Auth', () {
    late Auth auth, rejectedAccessTokenAuth, mockRequestHandlerAuth;

    setUp(() {
      reset(mockRequestHandler);
    });
    setUpAll(() {
      FirebaseAdmin.instance.setupTesting();
      var mockApp = admin.initializeApp(mocks.appOptions, mocks.appName);
      auth = mockApp.auth();

      rejectedAccessTokenAuth = admin
          .initializeApp(mocks.appOptionsRejectedWhileFetchingAccessToken,
              'rejected-access-token')
          .auth();

      AuthRequestHandler.factory = (app) => mockRequestHandler;
      mockRequestHandlerAuth =
          admin.initializeApp(mocks.appOptions, 'mock-request-handler').auth();
    });

    tearDownAll(() async {
      await auth.app.delete();
    });

    const email = 'user@example.com';
    var expectedLink =
        'https://custom.page.link?link=${Uri.encodeComponent('https://projectId.firebaseapp.com/__/auth/action?oobCode=CODE')}&apn=com.example.android&ibi=com.example.ios';

    group('Auth.generateSignInWithEmailLink()', () {
      var actionCodeSettings = ActionCodeSettings(
        url: 'https://www.example.com/path/file?a=1&b=2',
        handleCodeInApp: true,
        iosBundleId: 'com.example.ios',
        androidPackageName: 'com.example.android',
        androidInstallApp: true,
        androidMinimumVersion: '6',
        dynamicLinkDomain: 'custom.page.link',
      );
      var expectedError = FirebaseAuthError.userNotFound();

      test('should be rejected given an invalid email', () {
        expect(auth.generateSignInWithEmailLink('invalid', actionCodeSettings),
            throwsFirebaseError('auth/invalid-email'));
      });
      test('should be rejected given an invalid ActionCodeSettings object', () {
        expect(auth.generateSignInWithEmailLink(email, null),
            throwsFirebaseError('auth/argument-error'));
      });

      test(
          'should be rejected given an app which fails to generate access tokens',
          () {
        expect(
            rejectedAccessTokenAuth.generateSignInWithEmailLink(
                email, actionCodeSettings),
            throwsFirebaseError('app/invalid-credential'));
      });
      test(
          'should resolve when called with actionCodeSettings with a generated link on success',
          () async {
        // Stub getEmailActionLink to return expected link.
        when(mockRequestHandler.getEmailActionLink('EMAIL_SIGNIN', email,
                actionCodeSettings: actionCodeSettings))
            .thenAnswer((_) => Future.value(expectedLink));
        var actualLink = await mockRequestHandlerAuth
            .generateSignInWithEmailLink(email, actionCodeSettings);
        // Confirm expected user record response returned.
        expect(actualLink, expectedLink);
      });

      test('should throw an error when getEmailAction returns an error', () {
        // Stub getEmailActionLink to throw a backend error.
        when(mockRequestHandler.getEmailActionLink('EMAIL_SIGNIN', email,
                actionCodeSettings: actionCodeSettings))
            .thenAnswer((_) => throw expectedError);
        expect(
            () => mockRequestHandlerAuth.generateSignInWithEmailLink(
                email, actionCodeSettings),
            throwsA(expectedError));
      });

      test('should reject when called without actionCodeSettings', () {
        expect(auth.generateSignInWithEmailLink(email, null),
            throwsFirebaseError('auth/argument-error'));
      });
    });

    group('Auth.generateEmailVerificationLink()', () {
      test(
          'should resolve when called without actionCodeSettings with a generated link on success',
          () async {
        // Stub getEmailActionLink to return expected link.
        when(mockRequestHandler.getEmailActionLink('VERIFY_EMAIL', email))
            .thenAnswer((_) => Future.value(expectedLink));
        var actualLink =
            await mockRequestHandlerAuth.generateEmailVerificationLink(email);
        // Confirm expected user record response returned.
        expect(actualLink, expectedLink);
      });
    });
    group('Auth.generatePasswordResetLink()', () {
      test(
          'should resolve when called without actionCodeSettings with a generated link on success',
          () async {
        // Stub getEmailActionLink to return expected link.
        when(mockRequestHandler.getEmailActionLink('PASSWORD_RESET', email))
            .thenAnswer((_) => Future.value(expectedLink));
        var actualLink =
            await mockRequestHandlerAuth.generatePasswordResetLink(email);
        // Confirm expected user record response returned.
        expect(actualLink, expectedLink);
      });
    });

    group('Auth.getUser()', () {
      const uid = 'abcdefghijklmnopqrstuvwxyz';
      final expectedGetAccountInfoResult = _getValidGetAccountInfoResponse();
      final expectedUserRecord =
          UserRecord.fromJson(expectedGetAccountInfoResult['users'][0]);
      final expectedError = FirebaseAuthError.userNotFound();

      test('should be rejected given an invalid uid', () {
        expect(auth.getUser(List.filled(129, 'a').join()),
            throwsFirebaseError('auth/invalid-uid'));
      });

      test(
          'should be rejected given an app which fails to generate access tokens',
          () {
        expect(rejectedAccessTokenAuth.getUser(uid),
            throwsFirebaseError('app/invalid-credential'));
      });
      test('should resolve with a UserRecord on success', () async {
        // Stub getAccountInfoByUid to return expected result.
        when(mockRequestHandler.getAccountInfoByUid(uid))
            .thenAnswer((_) => Future.value(expectedGetAccountInfoResult));

        var userRecord = await mockRequestHandlerAuth.getUser(uid);
        // Confirm expected user record response returned.
        expect(userRecord.displayName, 'John Doe');
        expect(userRecord.uid, 'abcdefghijklmnopqrstuvwxyz');
        expect(userRecord.toJson(), expectedUserRecord.toJson());
      });

      test('should throw an error when the backend returns an error', () {
        // Stub getAccountInfoByUid to throw a backend error.
        when(mockRequestHandler.getAccountInfoByUid(uid))
            .thenAnswer((_) => throw expectedError);
        // Confirm expected error returned.
        expect(mockRequestHandlerAuth.getUser(uid), throwsA(expectedError));
      });
    });

    group('Auth.getUserByEmail()', () {
      const email = 'user@gmail.com';
      final expectedGetAccountInfoResult = _getValidGetAccountInfoResponse();
      final expectedUserRecord =
          UserRecord.fromJson(expectedGetAccountInfoResult['users'][0]);
      final expectedError = FirebaseAuthError.userNotFound();

      test('should be rejected given an invalid email', () {
        expect(auth.getUserByEmail('name-example-com'),
            throwsFirebaseError('auth/invalid-email'));
      });

      test(
          'should be rejected given an app which fails to generate access tokens',
          () {
        expect(rejectedAccessTokenAuth.getUserByEmail(email),
            throwsFirebaseError('app/invalid-credential'));
      });

      test('should resolve with a UserRecord on success', () async {
        // Stub getAccountInfoByEmail to return expected result.
        when(mockRequestHandler.getAccountInfoByEmail(email))
            .thenAnswer((_) async => expectedGetAccountInfoResult);
        var userRecord = await mockRequestHandlerAuth.getUserByEmail(email);
        // Confirm expected user record response returned.
        expect(userRecord.displayName, 'John Doe');
        expect(userRecord.uid, 'abcdefghijklmnopqrstuvwxyz');
        expect(userRecord.toJson(), expectedUserRecord.toJson());
      });

      test('should throw an error when the backend returns an error', () {
        // Stub getAccountInfoByEmail to throw a backend error.
        when(mockRequestHandler.getAccountInfoByEmail(email))
            .thenAnswer((_) => throw expectedError);
        // Confirm expected error returned.
        expect(mockRequestHandlerAuth.getUserByEmail(email),
            throwsA(expectedError));
      });
    });

    group('Auth.getUserByPhoneNumber()', () {
      const phoneNumber = '+11234567890';
      final expectedGetAccountInfoResult = _getValidGetAccountInfoResponse();
      final expectedUserRecord =
          UserRecord.fromJson(expectedGetAccountInfoResult['users'][0]);
      final expectedError = FirebaseAuthError.userNotFound();

      test('should be rejected given an invalid phone number', () {
        const invalidPhoneNumber = 'invalid';
        expect(auth.getUserByPhoneNumber(invalidPhoneNumber),
            throwsFirebaseError('auth/invalid-phone-number'));
      });

      test(
          'should be rejected given an app which fails to generate access tokens',
          () {
        expect(rejectedAccessTokenAuth.getUserByPhoneNumber(phoneNumber),
            throwsFirebaseError('app/invalid-credential'));
      });
      test('should resolve with a UserRecord on success', () async {
        // Stub getAccountInfoByPhoneNumber to return expected result.
        when(mockRequestHandler.getAccountInfoByPhoneNumber(phoneNumber))
            .thenAnswer((_) async => expectedGetAccountInfoResult);
        var userRecord =
            await mockRequestHandlerAuth.getUserByPhoneNumber(phoneNumber);
        // Confirm expected user record response returned.
        expect(userRecord.displayName, 'John Doe');
        expect(userRecord.uid, 'abcdefghijklmnopqrstuvwxyz');
        expect(userRecord.toJson(), expectedUserRecord.toJson());
      });
      test('should throw an error when the backend returns an error', () {
        // Stub getAccountInfoByPhoneNumber to throw a backend error.
        when(mockRequestHandler.getAccountInfoByPhoneNumber(phoneNumber))
            .thenAnswer((_) => throw expectedError);
        // Confirm expected error returned.
        expect(mockRequestHandlerAuth.getUserByPhoneNumber(phoneNumber),
            throwsA(expectedError));
      });
    });

    group('Auth.listUsers()', () {
      final expectedError = FirebaseAuthError.internalError();
      const pageToken = 'PAGE_TOKEN';
      const maxResult = 500;
      const downloadAccountResponse = {
        'users': [
          {'localId': 'UID1'},
          {'localId': 'UID2'},
          {'localId': 'UID3'},
        ],
        'nextPageToken': 'NEXT_PAGE_TOKEN',
      };
      final emptyDownloadAccountResponse = {
        'users': [],
      };

      test('should be rejected given an invalid page token', () {
        expect(auth.listUsers(null, ''),
            throwsFirebaseError('auth/invalid-page-token'));
      });
      test('should be rejected given an invalid max result', () {
        const invalidResults = 5000;
        expect(auth.listUsers(invalidResults),
            throwsFirebaseError('auth/argument-error'));
      });

      test(
          'should be rejected given an app which fails to generate access tokens',
          () {
        expect(rejectedAccessTokenAuth.listUsers(maxResult),
            throwsFirebaseError('app/invalid-credential'));
      });
      test(
          'should resolve on downloadAccount request success with users in response',
          () async {
        // Stub downloadAccount to return expected response.
        when(mockRequestHandler.downloadAccount(maxResult, pageToken))
            .thenAnswer((_) async => downloadAccountResponse);

        var response =
            await mockRequestHandlerAuth.listUsers(maxResult, pageToken);
        expect(response.pageToken, 'NEXT_PAGE_TOKEN');
        expect(response.users.length, 3);
        expect(response.users.first.uid, 'UID1');
      });
      test(
          'should resolve on downloadAccount request success with default options',
          () async {
        // Stub downloadAccount to return expected response.
        when(mockRequestHandler.downloadAccount(null, null))
            .thenAnswer((_) async => downloadAccountResponse);
        var response = await mockRequestHandlerAuth.listUsers();
        expect(response.pageToken, 'NEXT_PAGE_TOKEN');
        expect(response.users.length, 3);
        expect(response.users.first.uid, 'UID1');
      });
      test(
          'should resolve on downloadAccount request success with no users in response',
          () async {
        // Stub downloadAccount to return expected response.
        when(mockRequestHandler.downloadAccount(maxResult, pageToken))
            .thenAnswer((_) async => emptyDownloadAccountResponse);

        var response =
            await mockRequestHandlerAuth.listUsers(maxResult, pageToken);
        expect(response.users, isEmpty);
        expect(response.pageToken, isNull);
      });

      test('should throw an error when downloadAccount returns an error', () {
        // Stub downloadAccount to throw a backend error.
        when(mockRequestHandler.downloadAccount(maxResult, pageToken))
            .thenAnswer((_) => throw expectedError);
        expect(mockRequestHandlerAuth.listUsers(maxResult, pageToken),
            throwsA(expectedError));
      });
    });

    group('Auth.createUser()', () {
      const uid = 'abcdefghijklmnopqrstuvwxyz';
      final expectedGetAccountInfoResult = _getValidGetAccountInfoResponse();
      final expectedUserRecord =
          UserRecord.fromJson(expectedGetAccountInfoResult['users'][0]);
      final expectedError = FirebaseAuthError.internalError(
          'Unable to create the user record provided.');
      final request = CreateEditAccountRequest(
        displayName: expectedUserRecord.displayName,
        photoUrl: expectedUserRecord.photoUrl,
        email: expectedUserRecord.email,
        emailVerified: expectedUserRecord.emailVerified,
        password: 'password',
        phoneNumber: expectedUserRecord.phoneNumber,
      );

      Future<UserRecord> _createUser(Auth auth) => auth.createUser(
            displayName: expectedUserRecord.displayName,
            photoUrl: expectedUserRecord.photoUrl,
            email: expectedUserRecord.email,
            emailVerified: expectedUserRecord.emailVerified,
            password: 'password',
            phoneNumber: expectedUserRecord.phoneNumber,
          );

      test('should be rejected given no properties', () {
        expect(auth.createUser(), throwsFirebaseError('auth/argument-error'));
      });

      test(
          'should be rejected given an app which fails to generate access tokens',
          () {
        expect(_createUser(rejectedAccessTokenAuth),
            throwsFirebaseError('app/invalid-credential'));
      });

      test(
          'should resolve with a UserRecord on createNewAccount request success',
          () async {
        // Stub createNewAccount to return expected uid.
        when(mockRequestHandler.createNewAccount(request))
            .thenAnswer((_) async => uid);

        // Stub getAccountInfoByUid to return expected result.
        when(mockRequestHandler.getAccountInfoByUid(uid))
            .thenAnswer((_) async => expectedGetAccountInfoResult);
        var userRecord = await _createUser(mockRequestHandlerAuth);
        // Confirm expected user record response returned.
        expect(userRecord.toJson(), expectedUserRecord.toJson());
      });

      test('should throw an error when createNewAccount returns an error', () {
        // Stub createNewAccount to throw a backend error.
        when(mockRequestHandler.createNewAccount(request))
            .thenAnswer((_) => throw expectedError);
        expect(_createUser(mockRequestHandlerAuth), throwsA(expectedError));
      });

      test('should throw an error when getUser returns a User not found error',
          () {
        // Stub createNewAccount to return expected uid.
        when(mockRequestHandler.createNewAccount(request))
            .thenAnswer((_) async => uid);
        // Stub getAccountInfoByUid to throw user not found error.
        final userNotFoundError = FirebaseAuthError.userNotFound();
        when(mockRequestHandler.getAccountInfoByUid(uid))
            .thenAnswer((_) async => throw userNotFoundError);

        expect(_createUser(mockRequestHandlerAuth),
            throwsFirebaseError('auth/internal-error'));
      });

      test(
          'should echo getUser error if an error occurs while retrieving the user record',
          () {
        // Stub createNewAccount to return expected uid.
        when(mockRequestHandler.createNewAccount(request))
            .thenAnswer((_) async => uid);
        // Stub getAccountInfoByUid to throw expected error.
        when(mockRequestHandler.getAccountInfoByUid(uid))
            .thenAnswer((_) async => throw expectedError);

        expect(_createUser(mockRequestHandlerAuth), throwsA(expectedError));
      });
    });

    group('Auth.deleteUser()', () {
      const uid = 'abcdefghijklmnopqrstuvwxyz';
      const expectedDeleteAccountResult = {
        'kind': 'identitytoolkit#DeleteAccountResponse'
      };
      final expectedError = FirebaseAuthError.userNotFound();

      test('should be rejected given an invalid uid', () {
        final invalidUid = List.filled(129, 'a').join();
        expect(auth.deleteUser(invalidUid),
            throwsFirebaseError('auth/invalid-uid'));
      });

      test(
          'should be rejected given an app which fails to generate access tokens',
          () {
        expect(rejectedAccessTokenAuth.deleteUser(uid),
            throwsFirebaseError('app/invalid-credential'));
      });
      test('should resolve with void on success', () async {
        // Stub deleteAccount to return expected result.
        when(mockRequestHandler.deleteAccount(uid))
            .thenAnswer((_) async => expectedDeleteAccountResult);

        await mockRequestHandlerAuth.deleteUser(uid);
      });

      test('should throw an error when the backend returns an error', () {
        // Stub deleteAccount to throw a backend error.
        when(mockRequestHandler.deleteAccount(uid))
            .thenAnswer((_) async => throw expectedError);
        expect(mockRequestHandlerAuth.deleteUser(uid), throwsA(expectedError));
      });
    });

    group('Auth.updateUser()', () {
      const uid = 'abcdefghijklmnopqrstuvwxyz';
      final expectedGetAccountInfoResult = _getValidGetAccountInfoResponse();
      final expectedUserRecord =
          UserRecord.fromJson(expectedGetAccountInfoResult['users'][0]);
      final expectedError = FirebaseAuthError.userNotFound();

      final request = CreateEditAccountRequest(
        displayName: expectedUserRecord.displayName,
        photoUrl: expectedUserRecord.photoUrl,
        email: expectedUserRecord.email,
        emailVerified: expectedUserRecord.emailVerified,
        password: 'password',
        phoneNumber: expectedUserRecord.phoneNumber,
        uid: uid,
      );

      Future<UserRecord> _updateUser(Auth auth, String uid) => auth.updateUser(
            uid,
            displayName: expectedUserRecord.displayName,
            photoUrl: expectedUserRecord.photoUrl,
            email: expectedUserRecord.email,
            emailVerified: expectedUserRecord.emailVerified,
            password: 'password',
            phoneNumber: expectedUserRecord.phoneNumber,
          );

      test('should be rejected given an invalid uid', () {
        final invalidUid = List.filled(129, 'a').join();
        expect(_updateUser(auth, invalidUid),
            throwsFirebaseError('auth/invalid-uid'));
      });
      test('should be rejected given no properties', () {
        expect(
            auth.updateUser(uid), throwsFirebaseError('auth/argument-error'));
      });

      test(
          'should be rejected given an app which fails to generate access tokens',
          () {
        expect(_updateUser(rejectedAccessTokenAuth, uid),
            throwsFirebaseError('app/invalid-credential'));
      });
      test(
          'should resolve with a UserRecord on updateExistingAccount request success',
          () async {
        // Stub updateExistingAccount to return expected uid.
        when(mockRequestHandler.updateExistingAccount(uid, request))
            .thenAnswer((_) async => uid);
        // Stub getAccountInfoByUid to return expected result.
        when(mockRequestHandler.getAccountInfoByUid(uid))
            .thenAnswer((_) async => expectedGetAccountInfoResult);
        var userRecord = await _updateUser(mockRequestHandlerAuth, uid);
        expect(userRecord.toJson(), expectedUserRecord.toJson());
      });
      test('should throw an error when updateExistingAccount returns an error',
          () async {
        // Stub updateExistingAccount to throw a backend error.
        when(mockRequestHandler.updateExistingAccount(uid, request))
            .thenThrow(expectedError);
        expect(
            _updateUser(mockRequestHandlerAuth, uid), throwsA(expectedError));
      });
      test(
          'should echo getUser error if an error occurs while retrieving the user record',
          () async {
        // Stub updateExistingAccount to return expected uid.
        when(mockRequestHandler.updateExistingAccount(uid, request))
            .thenAnswer((_) async => uid);
        // Stub getAccountInfoByUid to throw an expected error.
        when(mockRequestHandler.getAccountInfoByUid(uid))
            .thenThrow(expectedError);
        expect(
            _updateUser(mockRequestHandlerAuth, uid), throwsA(expectedError));
      });
    });

    group('Auth.setCustomUserClaims()', () {
      const uid = 'abcdefghijklmnopqrstuvwxyz';
      final expectedError = FirebaseAuthError.userNotFound();
      const customClaims = {
        'admin': true,
        'groupId': '123456',
      };

      test('should be rejected given an invalid uid', () {
        final invalidUid = List.filled(129, 'a').join();
        expect(auth.setCustomUserClaims(invalidUid, customClaims),
            throwsFirebaseError('auth/invalid-uid'));
      });

      test(
          'should be rejected given an app which fails to generate access tokens',
          () {
        expect(rejectedAccessTokenAuth.setCustomUserClaims(uid, customClaims),
            throwsFirebaseError('app/invalid-credential'));
      });
      test('should resolve on setCustomUserClaims request success', () async {
        // Stub setCustomUserClaims to return expected uid.
        when(mockRequestHandler.setCustomUserClaims(uid, customClaims))
            .thenAnswer((_) async => uid);
        await mockRequestHandlerAuth.setCustomUserClaims(uid, customClaims);
        verify(mockRequestHandlerAuth.setCustomUserClaims(uid, customClaims))
            .called(1);
      });
      test('should throw an error when setCustomUserClaims returns an error',
          () {
        // Stub setCustomUserClaims to throw a backend error.
        when(mockRequestHandler.setCustomUserClaims(uid, customClaims))
            .thenThrow(expectedError);
        expect(mockRequestHandlerAuth.setCustomUserClaims(uid, customClaims),
            throwsA(expectedError));
      });
    });

    group('Auth.revokeRefreshTokens()', () {
      const uid = 'abcdefghijklmnopqrstuvwxyz';
      final expectedError = FirebaseAuthError.userNotFound();

      test('should be rejected given an invalid uid', () {
        final invalidUid = List.filled(129, 'a').join();
        expect(auth.revokeRefreshTokens(invalidUid),
            throwsFirebaseError('auth/invalid-uid'));
      });

      test(
          'should be rejected given an app which fails to generate access tokens',
          () {
        expect(rejectedAccessTokenAuth.revokeRefreshTokens(uid),
            throwsFirebaseError('app/invalid-credential'));
      });
      test('should resolve on underlying revokeRefreshTokens request success',
          () async {
        // Stub revokeRefreshTokens to return expected uid.
        when(mockRequestHandler.revokeRefreshTokens(uid))
            .thenAnswer((_) async => uid);
        await mockRequestHandlerAuth.revokeRefreshTokens(uid);
        // Confirm underlying API called with expected parameters.
        verify(mockRequestHandlerAuth.revokeRefreshTokens(uid)).called(1);
      });
      test(
          'should throw when underlying revokeRefreshTokens request returns an error',
          () {
        // Stub revokeRefreshTokens to throw a backend error.
        when(mockRequestHandler.revokeRefreshTokens(uid))
            .thenThrow(expectedError);
        expect(mockRequestHandlerAuth.revokeRefreshTokens(uid),
            throwsA(expectedError));
      });
    });

    group('Auth.verifyIdToken()', () {
      late String mockIdToken;
      final expectedAccountInfoResponse = _getValidGetAccountInfoResponse();
      final expectedUserRecord =
          UserRecord.fromJson(expectedAccountInfoResponse['users'][0]);
      final validSince = expectedUserRecord.tokensValidAfterTime;

      setUp(() {
        mockIdToken = mocks.generateIdToken();
      });

      test(
          'should be fulfilled given an app which fails to generate access tokens',
          () async {
        // verifyIdToken() does not rely on an access token and therefore works in this scenario.
        var token = await rejectedAccessTokenAuth.verifyIdToken(mockIdToken);
        expect(token, isNotNull);
        expect(token.claims.subject, 'someUid');
      });
      test(
          'should be fulfilled with checkRevoked set to true using an unrevoked ID token',
          () async {
        when(mockRequestHandler.getAccountInfoByUid('someUid'))
            .thenAnswer((_) async => expectedAccountInfoResponse);
        // Verify ID token while checking if revoked.
        var result =
            await mockRequestHandlerAuth.verifyIdToken(mockIdToken, true);
        verify(mockRequestHandler.getAccountInfoByUid('someUid')).called(1);
        expect(result, isNotNull);
      });
      test(
          'should be rejected with checkRevoked set to true using a revoked ID token',
          () {
        // One second before validSince.
        final oneSecBeforeValidSince =
            validSince!.subtract(Duration(seconds: 1));
        // Simulate revoked ID token returned with auth_time one second before validSince.
        var mockIdToken = mocks.generateIdToken({
          'auth_time': oneSecBeforeValidSince.millisecondsSinceEpoch ~/ 1000
        });
        when(mockRequestHandler.getAccountInfoByUid('someUid'))
            .thenAnswer((_) async => expectedAccountInfoResponse);

        // Verify ID token while checking if revoked.
        expect(mockRequestHandlerAuth.verifyIdToken(mockIdToken, true),
            throwsFirebaseError('auth/id-token-revoked'));
      });
      test(
          'should be fulfilled with checkRevoked set to false using a revoked ID token',
          () async {
        // One second before validSince.
        final oneSecBeforeValidSince =
            validSince!.subtract(Duration(seconds: 1));
        // Simulate revoked ID token returned with auth_time one second before validSince.
        var mockIdToken = mocks.generateIdToken({
          'auth_time': oneSecBeforeValidSince.millisecondsSinceEpoch ~/ 1000
        });
        when(mockRequestHandler.getAccountInfoByUid('someUid'))
            .thenAnswer((_) async => expectedAccountInfoResponse);

        // Verify ID token without checking if revoked.
        // This call should succeed.
        var result =
            await mockRequestHandlerAuth.verifyIdToken(mockIdToken, false);
        verifyNever(mockRequestHandler.getAccountInfoByUid('someUid'));
        expect(result, isNotNull);
      });
      test(
          'should be rejected with checkRevoked set to true if underlying RPC fails',
          () {
        final expectedError = FirebaseAuthError.userNotFound();
        when(mockRequestHandler.getAccountInfoByUid('someUid'))
            .thenThrow(expectedError);
        // Verify ID token while checking if revoked.
        // This should fail with the underlying RPC error.
        expect(mockRequestHandlerAuth.verifyIdToken(mockIdToken, true),
            throwsA(expectedError));
      });
      test(
          'should be fulfilled with checkRevoked set to true when no validSince available',
          () async {
        // Simulate no validSince set on the user.
        final noValidSinceGetAccountInfoResponse = {
          'users': [
            <String, dynamic>{...expectedAccountInfoResponse['users'][0]}
              ..remove('validSince')
          ]
        };
        // Confirm null tokensValidAfterTime on user.
        expect(
            UserRecord.fromJson(noValidSinceGetAccountInfoResponse['users']![0])
                .tokensValidAfterTime,
            isNull);
        // Simulate getUser returns the expected user with no validSince.
        when(mockRequestHandler.getAccountInfoByUid('someUid'))
            .thenAnswer((_) async => noValidSinceGetAccountInfoResponse);
        verifyNever(mockRequestHandler.getAccountInfoByUid('someUid'));
        // Verify ID token while checking if revoked.
        var result =
            await mockRequestHandlerAuth.verifyIdToken(mockIdToken, true);
        // Confirm underlying API called with expected parameters.
        verify(mockRequestHandler.getAccountInfoByUid('someUid')).called(1);
        expect(result, isNotNull);
      });
    });

    group('Auth.createCustomToken()', () {
      test('should create a signed JWT', () async {
        var token = await auth.createCustomToken(uid, {'isAdmin': true});
        var decodedToken = IdToken.unverified(token);
        expect(decodedToken.claims['uid'], uid);
        expect(decodedToken.claims['isAdmin'], isTrue);

        var jwks = JsonWebKeySet.fromJson(json.decode(
            File('test/resources/openid-jwks.json').readAsStringSync()));

        var verified =
            await decodedToken.verify(JsonWebKeyStore()..addKeySet(jwks));
        expect(verified, true);
      });
    });
  });
}

Map<String, dynamic> _getValidGetAccountInfoResponse() {
  final userResponse = {
    'localId': 'abcdefghijklmnopqrstuvwxyz',
    'email': 'user@gmail.com',
    'emailVerified': true,
    'displayName': 'John Doe',
    'phoneNumber': '+11234567890',
    'providerUserInfo': [
      {
        'providerId': 'google.com',
        'displayName': 'John Doe',
        'photoUrl': 'https://lh3.googleusercontent.com/1234567890/photo.jpg',
        'federatedId': '1234567890',
        'email': 'user@gmail.com',
        'rawId': '1234567890',
      },
      {
        'providerId': 'facebook.com',
        'displayName': 'John Smith',
        'photoUrl': 'https://facebook.com/0987654321/photo.jpg',
        'federatedId': '0987654321',
        'email': 'user@facebook.com',
        'rawId': '0987654321',
      },
      {
        'providerId': 'phone',
        'phoneNumber': '+11234567890',
        'rawId': '+11234567890',
      },
    ],
    'photoUrl': 'https://lh3.googleusercontent.com/1234567890/photo.jpg',
    'validSince': '1476136676',
    'lastLoginAt': '1476235905000',
    'createdAt': '1476136676000',
  };
  return {
    'kind': 'identitytoolkit#GetAccountInfoResponse',
    'users': [userResponse],
  };
}
