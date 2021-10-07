import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_admin/src/auth/token_generator.dart';
import 'package:firebase_admin/src/auth/token_verifier.dart';
import 'package:openid_client/openid_client.dart';

import 'app.dart';
import 'auth/auth_api_request.dart';
import 'auth/user_record.dart';
import 'service.dart';

export 'auth/user_record.dart';

/// The Firebase Auth service interface.
class Auth implements FirebaseService {
  @override
  final App app;

  final AuthRequestHandler _authRequestHandler;
  final FirebaseTokenVerifier _tokenVerifier;
  final FirebaseTokenGenerator _tokenGenerator;

  /// Do not call this constructor directly. Instead, use app().auth.
  Auth(this.app)
      : _authRequestHandler = AuthRequestHandler(app),
        _tokenVerifier = FirebaseTokenVerifier.factory(app),
        _tokenGenerator = FirebaseTokenGenerator.factory(app);

  @override
  Future<void> delete() async {
    // TODO: implement delete
  }

  /// Gets the user data for the user corresponding to a given [uid].
  Future<UserRecord> getUser(String uid) async {
    var response = await _authRequestHandler.getAccountInfoByUid(uid);
    // Returns the user record populated with server response.
    return UserRecord.fromJson(response['users'][0]);
  }

  /// Gets the user data for the users corresponding to the given [uids].
  Future<List<UserRecord>> getUsers(List<String> uids) async {
    var response = await _authRequestHandler.getAccountInfoByUids(uids);
    // Returns the user record populated with server response.
    return (response['users'] as List)
        .map((u) => UserRecord.fromJson(u))
        .toList();
  }

  /// Looks up the user identified by the provided email and returns a future
  /// that is fulfilled with a user record for the given user if that user is
  /// found.
  Future<UserRecord> getUserByEmail(String email) async {
    var response = await _authRequestHandler.getAccountInfoByEmail(email);
    // Returns the user record populated with server response.
    return UserRecord.fromJson(response['users'][0]);
  }

  /// Looks up the user identified by the provided phone number and returns a
  /// future that is fulfilled with a user record for the given user if that
  /// user is found.
  Future<UserRecord> getUserByPhoneNumber(String phoneNumber) async {
    var response =
        await _authRequestHandler.getAccountInfoByPhoneNumber(phoneNumber);
    // Returns the user record populated with server response.
    return UserRecord.fromJson(response['users'][0]);
  }

  /// Retrieves a list of users (single batch only) with a size of [maxResults]
  /// and starting from the offset as specified by [pageToken].
  ///
  /// This is used to retrieve all the users of a specified project in batches.
  Future<ListUsersResult> listUsers(
      [num? maxResults, String? pageToken]) async {
    var response = await _authRequestHandler.downloadAccount(
        maxResults as int?, pageToken);
    return ListUsersResult.fromJson(response);
  }

  /// Creates a new user.
  Future<UserRecord> createUser({
    bool? disabled,
    String? displayName,
    String? email,
    bool? emailVerified,
    String? password,
    String? phoneNumber,
    String? photoUrl,
    String? uid,
  }) async {
    try {
      uid = await _authRequestHandler.createNewAccount(CreateEditAccountRequest(
          disabled: disabled,
          displayName: displayName,
          email: email,
          emailVerified: emailVerified,
          password: password,
          phoneNumber: phoneNumber,
          photoUrl: photoUrl,
          uid: uid));
      // Return the corresponding user record.
      return await getUser(uid);
    } on FirebaseException catch (error) {
      if (error.code == 'auth/user-not-found') {
        // Something must have happened after creating the user and then retrieving it.
        throw FirebaseAuthError.internalError(
            'Unable to create the user record provided.');
      }
      rethrow;
    }
  }

  /// Deletes an existing user.
  Future<void> deleteUser(String uid) async {
    await _authRequestHandler.deleteAccount(uid);
  }

  /// Updates an existing user.
  ///
  /// Set [displayName], [photoUrl] and/or [phoneNumber] to the empty string to
  /// remove them from the user record. When phone number is removed, also the
  /// corresponding provider will be removed.
  Future<UserRecord> updateUser(
    String uid, {
    bool? disabled,
    String? displayName,
    String? email,
    bool? emailVerified,
    String? password,
    String? phoneNumber,
    String? photoUrl,
  }) async {
    uid = await _authRequestHandler.updateExistingAccount(
        uid,
        CreateEditAccountRequest(
            disabled: disabled,
            displayName: displayName,
            email: email,
            emailVerified: emailVerified,
            password: password,
            phoneNumber: phoneNumber,
            photoUrl: photoUrl,
            uid: uid));
    // Return the corresponding user record.
    return await getUser(uid);
  }

  /// Sets additional developer claims on an existing user identified by the
  /// provided uid, typically used to define user roles and levels of access.
  ///
  /// These claims should propagate to all devices where the user is already
  /// signed in (after token expiration or when token refresh is forced) and the
  /// next time the user signs in. If a reserved OIDC claim name is used
  /// (sub, iat, iss, etc), an error is thrown. They will be set on the
  /// authenticated user's ID token JWT.
  ///
  /// [customUserClaims] can be `null`.
  ///
  /// Returns a promise containing `void`.
  Future<void> setCustomUserClaims(
      String uid, Map<String, dynamic> customUserClaims) async {
    await _authRequestHandler.setCustomUserClaims(uid, customUserClaims);
  }

  /// Revokes all refresh tokens for an existing user.
  ///
  /// This API will update the user's [UserRecord.tokensValidAfterTime] to the
  /// current UTC. It is important that the server on which this is called has
  /// its clock set correctly and synchronized.
  ///
  /// While this will revoke all sessions for a specified user and disable any
  /// new ID tokens for existing sessions from getting minted, existing ID tokens
  /// may remain active until their natural expiration (one hour). To verify that
  /// ID tokens are revoked, use [Auth.verifyIdToken] where `checkRevoked` is set
  /// to `true`.
  Future<void> revokeRefreshTokens(String uid) async {
    await _authRequestHandler.revokeRefreshTokens(uid);
  }

  /// Generates the out of band email action link for password reset flows for
  /// the email specified using the action code settings provided.
  Future<String> generatePasswordResetLink(String email,
      [ActionCodeSettings? actionCodeSettings]) {
    return _authRequestHandler.getEmailActionLink('PASSWORD_RESET', email,
        actionCodeSettings: actionCodeSettings);
  }

  /// Generates the out of band email action link for email verification flows
  /// for the email specified using the action code settings provided.
  Future<String> generateEmailVerificationLink(String email,
      [ActionCodeSettings? actionCodeSettings]) {
    return _authRequestHandler
        .getEmailActionLink('VERIFY_EMAIL', email,
            actionCodeSettings: actionCodeSettings)
        .then((value) => value);
  }

  /// Generates the out of band email action link for email link sign-in flows
  /// for the email specified using the action code settings provided.
  Future<String> generateSignInWithEmailLink(
      String email, ActionCodeSettings? actionCodeSettings) {
    return _authRequestHandler
        .getEmailActionLink('EMAIL_SIGNIN', email,
            actionCodeSettings: actionCodeSettings)
        .then((value) => value);
  }

  /// Verifies a Firebase ID token (JWT).
  ///
  /// If the token is valid, the returned [Future] is completed with an instance
  /// of [IdToken]; otherwise, the future is completed with an error.
  /// An optional flag can be passed to additionally check whether the ID token
  /// was revoked.
  Future<IdToken> verifyIdToken(String idToken,
      [bool checkRevoked = false]) async {
    var decodedIdToken = await _tokenVerifier.verifyJwt(idToken);
    // Whether to check if the token was revoked.
    if (!checkRevoked) {
      return decodedIdToken;
    }
    return _verifyDecodedJwtNotRevoked(decodedIdToken);
  }

  /// Creates a new Firebase custom token (JWT) that can be sent back to a client
  /// device to use to sign in with the client SDKs' signInWithCustomToken()
  /// methods.
  ///
  /// Returns a [Future] containing a custom token string for the provided [uid]
  /// and payload.
  Future<String> createCustomToken(String uid,
      [Map<String, dynamic> developerClaims = const {}]) async {
    return _tokenGenerator.createCustomToken(uid, developerClaims);
  }

  /// Verifies the decoded Firebase issued JWT is not revoked. Returns a future
  /// that resolves with the decoded claims on success. Rejects the future with
  /// revocation error if revoked.
  Future<IdToken> _verifyDecodedJwtNotRevoked(IdToken decodedIdToken) async {
    // Get tokens valid after time for the corresponding user.
    var user = await getUser(decodedIdToken.claims.subject);
    // If no tokens valid after time available, token is not revoked.
    if (user.tokensValidAfterTime != null) {
      // Get the ID token authentication time.
      final authTimeUtc = decodedIdToken.claims.authTime!;
      // Get user tokens valid after time.
      final validSinceUtc = user.tokensValidAfterTime!;
      // Check if authentication time is older than valid since time.
      if (authTimeUtc.isBefore(validSinceUtc)) {
        throw FirebaseAuthError.idTokenRevoked();
      }
    }
    // All checks above passed. Return the decoded token.
    return decodedIdToken;
  }
}

/// Defines the required continue/state URL with optional Android and iOS
/// settings.
///
/// Used when invoking the email action link generation APIs in FirebaseAuth.
class ActionCodeSettings {
  /// The link continue/state URL
  final String url;

  /// Specifies whether to open the link via a mobile app or a browser
  final bool? handleCodeInApp;

  /// The bundle ID of the iOS app where the link should be handled if the
  /// application is already installed on the device.
  final String? iosBundleId;

  /// The Android package name of the app where the link should be handled if
  /// the Android app is installed.
  final String? androidPackageName;

  /// Specifies whether to install the Android app if the device supports it and
  /// the app is not already installed.
  final bool? androidInstallApp;

  /// The minimum version for Android app.
  final String? androidMinimumVersion;

  /// The dynamic link domain to use for the current link if it is to be opened
  /// using Firebase Dynamic Links, as multiple dynamic link domains can be
  /// configured per project.
  final String? dynamicLinkDomain;

  ActionCodeSettings(
      {required this.url,
      this.handleCodeInApp,
      this.iosBundleId,
      this.androidPackageName,
      this.androidInstallApp,
      this.androidMinimumVersion,
      this.dynamicLinkDomain});
}

/// Response object for a listUsers operation.
class ListUsersResult {
  final List<UserRecord> users;
  final String? pageToken;

  ListUsersResult({required this.users, this.pageToken});

  ListUsersResult.fromJson(Map<String, dynamic> map)
      : this(
            users: (map['users'] as List)
                .map((v) => UserRecord.fromJson(v))
                .toList(),
            pageToken: map['nextPageToken']);
}
