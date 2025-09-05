import 'dart:convert';

import 'package:clock/clock.dart';

import '../auth.dart';
import '../app/app_extension.dart';
import '../utils/api_request.dart';
import '../utils/error.dart';

import '../app.dart';
import '../utils/validator.dart' as validator;
import 'identitytoolkit.dart';

class AuthRequestHandler {
  final IdentityToolkitApi identityToolkitApi;

  final String projectId;

  static AuthRequestHandler Function(App app) factory =
      (app) => AuthRequestHandler._(app);

  factory AuthRequestHandler(App app) => factory(app);
  AuthRequestHandler._(App app)
      : projectId = app.projectId,
        identityToolkitApi = IdentityToolkitApi(AuthorizedHttpClient(app));

  /// Maximum allowed number of users to batch download at one time.
  static const maxDownloadAccountPageSize = 1000;

  /// Looks up a user by uid.
  Future<UserRecord> getAccountInfoByUid(String uid, {String? tenantId}) async {
    if (!validator.isUid(uid)) {
      throw FirebaseAuthError.invalidUid();
    }
    return _getAccountInfo(localId: [uid], tenantId: tenantId);
  }

  /// Looks up a user by email.
  Future<UserRecord> getAccountInfoByEmail(String email,
      {String? tenantId}) async {
    if (!validator.isEmail(email)) {
      throw FirebaseAuthError.invalidEmail();
    }
    return _getAccountInfo(email: [email], tenantId: tenantId);
  }

  /// Looks up a user by phone number.
  Future<UserRecord> getAccountInfoByPhoneNumber(String phoneNumber,
      {String? tenantId}) async {
    if (!validator.isPhoneNumber(phoneNumber)) {
      throw FirebaseAuthError.invalidPhoneNumber();
    }
    return _getAccountInfo(phoneNumber: [phoneNumber], tenantId: tenantId);
  }

  Future<UserRecord> _getAccountInfo(
      {List<String>? phoneNumber,
      List<String>? email,
      List<String>? localId,
      String? tenantId}) async {
    var response = await identityToolkitApi.projects.accounts_1.lookup(
        GoogleCloudIdentitytoolkitV1GetAccountInfoRequest()
          ..phoneNumber = phoneNumber
          ..email = email
          ..localId = localId
          ..tenantId = tenantId,
        projectId);

    if (response.users == null || response.users!.isEmpty) {
      throw FirebaseAuthError.userNotFound();
    }

    return UserRecord.fromJson(_deepToJson(response.users!.first));
  }

  /// Exports the users (single batch only) with a size of maxResults and
  /// starting from the offset as specified by pageToken.
  Future<ListUsersResult> downloadAccount(int? maxResults, String? pageToken,
      {String? tenantId}) async {
    // Validate next page token.
    if (pageToken != null && pageToken.isEmpty) {
      throw FirebaseAuthError.invalidPageToken();
    }

    // Validate max results.
    maxResults ??= maxDownloadAccountPageSize;
    if (maxResults <= 0 || maxResults > maxDownloadAccountPageSize) {
      throw FirebaseAuthError.invalidArgument(
          'Required "maxResults" must be a positive integer that does not exceed $maxDownloadAccountPageSize.');
    }

    var response = await identityToolkitApi.projects.accounts_1.batchGet(
        projectId,
        maxResults: maxResults,
        nextPageToken: pageToken,
        tenantId: tenantId);

    return ListUsersResult(
        users: response.users
                ?.map((u) => UserRecord.fromJson(_deepToJson(u)))
                .toList() ??
            [],
        pageToken: response.nextPageToken);
  }

  /// Create a new user with the properties supplied.
  Future<String> createNewAccount({
    bool? disabled,
    String? displayName,
    String? email,
    bool? emailVerified,
    String? password,
    String? phoneNumber,
    String? photoUrl,
    String? uid,
    List<CreateMultiFactorInfoRequest>? multiFactorEnrolledFactors,
    String? tenantId,
  }) async {
    _validateAccountParameters(
      uid: uid,
      disabled: disabled,
      displayName: displayName,
      email: email,
      emailVerified: emailVerified,
      password: password,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
      multiFactorEnrolledFactors: multiFactorEnrolledFactors,
    );

    var response = await identityToolkitApi.projects.accounts(
        GoogleCloudIdentitytoolkitV1SignUpRequest()
          ..disabled = disabled
          ..displayName = displayName
          ..email = email
          ..emailVerified = emailVerified
          ..password = password
          ..phoneNumber = phoneNumber
          ..photoUrl = photoUrl
          ..localId = uid
          ..mfaInfo = multiFactorEnrolledFactors
              ?.map((v) => GoogleCloudIdentitytoolkitV1MfaFactor(
                  displayName: v.displayName,
                  phoneInfo: v is CreatePhoneMultiFactorInfoRequest
                      ? v.phoneNumber
                      : null))
              .toList()
          ..tenantId = tenantId,
        projectId);

    // If the localId is not returned, then the request failed.
    if (response.localId == null) {
      throw FirebaseAuthError.internalError(
          'INTERNAL ASSERT FAILED: Unable to create new user');
    }

    return response.localId!;
  }

  /// Deletes an account identified by a uid.
  Future<void> deleteAccount(String uid, {String? tenantId}) async {
    if (!validator.isUid(uid)) {
      throw FirebaseAuthError.invalidUid();
    }

    await identityToolkitApi.projects.accounts_1.delete(
        GoogleCloudIdentitytoolkitV1DeleteAccountRequest()
          ..localId = uid
          ..tenantId = tenantId,
        projectId);
  }

  /// Edits an existing user.
  Future<String> updateExistingAccount(
    String uid, {
    bool? disableUser,
    String? displayName,
    String? email,
    bool? emailVerified,
    String? password,
    String? phoneNumber,
    String? photoUrl,
    List<UpdateMultiFactorInfoRequest>? multiFactorEnrolledFactors,
    String? tenantId,
  }) async {
    _validateAccountParameters(
      uid: uid,
      disabled: disableUser,
      displayName: displayName,
      email: email,
      emailVerified: emailVerified,
      password: password,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
      multiFactorEnrolledFactors: multiFactorEnrolledFactors,
    );

    return _setAccountInfo(GoogleCloudIdentitytoolkitV1SetAccountInfoRequest(
        localId: uid,
        disableUser: disableUser,
        displayName: displayName,
        email: email,
        emailVerified: emailVerified,
        password: password,
        phoneNumber: phoneNumber,
        photoUrl: photoUrl,
        mfa: multiFactorEnrolledFactors == null
            ? null
            : GoogleCloudIdentitytoolkitV1MfaInfo(
                enrollments: multiFactorEnrolledFactors
                    .map((v) => GoogleCloudIdentitytoolkitV1MfaEnrollment(
                        displayName: v.displayName,
                        enrolledAt: v.enrollmentTime?.toUtc().toIso8601String(),
                        mfaEnrollmentId: v.uid,
                        phoneInfo: v is UpdatePhoneMultiFactorInfoRequest
                            ? v.phoneNumber
                            : null))
                    .toList()),
        tenantId: tenantId));
  }

  void _validateAccountParameters({
    bool? disabled,
    String? displayName,
    String? email,
    bool? emailVerified,
    String? password,
    String? phoneNumber,
    String? photoUrl,
    String? uid,
    List<dynamic>? multiFactorEnrolledFactors,
  }) {
    if (disabled == null &&
        displayName == null &&
        email == null &&
        emailVerified == null &&
        password == null &&
        phoneNumber == null &&
        photoUrl == null &&
        multiFactorEnrolledFactors == null) {
      throw FirebaseAuthError.invalidArgument();
    }

    if (uid != null && !validator.isUid(uid)) {
      // This is called localId on the backend but the developer specifies this as
      // uid externally. So the error message should use the client facing name.
      throw FirebaseAuthError.invalidUid();
    }

    // email should be a string and a valid email.
    if (email != null && !validator.isEmail(email)) {
      throw FirebaseAuthError.invalidEmail();
    }
    // phoneNumber should be a string and a valid phone number.
    if (phoneNumber != null && !validator.isPhoneNumber(phoneNumber)) {
      throw FirebaseAuthError.invalidPhoneNumber();
    }

    // password should be a string and a minimum of 6 chars.
    if (password != null && !validator.isPassword(password)) {
      throw FirebaseAuthError.invalidPassword();
    }

    // photoUrl should be a URL.
    if (photoUrl != null && !validator.isUrl(photoUrl)) {
      // This is called photoUrl on the backend but the developer specifies this as
      // photoURL externally. So the error message should use the client facing name.
      throw FirebaseAuthError.invalidPhotoUrl();
    }
  }

  /// Sets additional developer claims on an existing user identified by
  /// provided UID.
  Future<String> setCustomUserClaims(
      String uid, Map<String, dynamic>? customUserClaims,
      {String? tenantId}) async {
    // Validate user UID.
    if (!validator.isUid(uid)) {
      throw FirebaseAuthError.invalidUid();
    }

    // Delete operation. Replace null with an empty object.
    customUserClaims ??= {};

    return _setAccountInfo(GoogleCloudIdentitytoolkitV1SetAccountInfoRequest(
        localId: uid,
        customAttributes: json.encode(customUserClaims),
        tenantId: tenantId));
  }

  /// Revokes all refresh tokens for the specified user identified by the uid
  /// provided.
  ///
  /// In addition to revoking all refresh tokens for a user, all ID tokens
  /// issued before revocation will also be revoked on the Auth backend. Any
  /// request with an ID token generated before revocation will be rejected with
  /// a token expired error.
  ///
  /// Note that due to the fact that the timestamp is stored in seconds, any
  /// tokens minted in the same second as the revocation will still be valid. If
  /// there is a chance that a token was minted in the last second, delay for 1
  /// second before revoking.
  Future<String> revokeRefreshTokens(String uid, {String? tenantId}) async {
    // Validate user UID.
    if (!validator.isUid(uid)) {
      throw FirebaseAuthError.invalidUid();
    }
    return await _setAccountInfo(
        GoogleCloudIdentitytoolkitV1SetAccountInfoRequest(
            localId: uid,
            validSince: '${clock.now().millisecondsSinceEpoch ~/ 1000}',
            tenantId: tenantId));
  }

  Future<String> _setAccountInfo(
      GoogleCloudIdentitytoolkitV1SetAccountInfoRequest request) async {
    var response =
        await identityToolkitApi.projects.accounts_1.update(request, projectId);

    // If the localId is not returned, then the request failed.
    if (response.localId == null) {
      throw FirebaseAuthError.userNotFound();
    }

    return response.localId!;
  }

  /// Generates the out of band email action link for the email specified using
  /// the action code settings provided.
  ///
  /// Returns a future that resolves with the generated link.
  ///
  /// The request type [requestType], could be either used for password reset,
  /// email verification, email link sign-in.
  ///
  /// [email] is the email of the user the link is being sent to.
  ///
  /// The optional [actionCodeSettings] defines whether the link is to be
  /// handled by a mobile app and the additional state information to be passed
  /// in the deep link, etc. Required when requestType == 'EMAIL_SIGNIN'
  Future<String> getEmailActionLink(String requestType, String email,
      {ActionCodeSettings? actionCodeSettings, String? tenantId}) async {
    if (!validator.isEmail(email)) {
      throw FirebaseAuthError.invalidEmail();
    }
    if (![
      'PASSWORD_RESET',
      'VERIFY_EMAIL',
      'EMAIL_SIGNIN',
    ].contains(requestType)) {
      throw FirebaseAuthError.invalidArgument(
        '"requestType" is not a supported email action request type.',
      );
    }

    // ActionCodeSettings required for email link sign-in to determine the url where the sign-in will
    // be completed.
    if (actionCodeSettings == null && requestType == 'EMAIL_SIGNIN') {
      throw FirebaseAuthError.invalidArgument(
        "`actionCodeSettings` is required when `requestType` == 'EMAIL_SIGNIN'",
      );
    }

    var response = await identityToolkitApi.projects.accounts_1.sendOobCode(
        GoogleCloudIdentitytoolkitV1GetOobCodeRequest()
          ..requestType = requestType
          ..email = email
          ..returnOobLink = true
          ..continueUrl = actionCodeSettings?.url
          ..canHandleCodeInApp = actionCodeSettings?.handleCodeInApp
          ..dynamicLinkDomain = actionCodeSettings?.dynamicLinkDomain
          ..iOSBundleId = actionCodeSettings?.iosBundleId
          ..androidPackageName = actionCodeSettings?.androidPackageName
          ..androidInstallApp = actionCodeSettings?.androidInstallApp
          ..androidMinimumVersion = actionCodeSettings?.androidMinimumVersion
          ..androidInstallApp = actionCodeSettings?.androidInstallApp
          ..tenantId = tenantId,
        projectId);

    // If the oobLink is not returned, then the request failed.
    if (response.oobLink == null) {
      throw FirebaseAuthError.internalError(
          'INTERNAL ASSERT FAILED: Unable to create the email action link');
    }

    // Return the link.
    return response.oobLink!;
  }
}

dynamic _deepToJson(dynamic v) {
  if (v is Map<String, dynamic>) {
    return v.map<String, dynamic>((k, v) => MapEntry(k, _deepToJson(v)));
  }
  if (v is List<dynamic>) {
    return v.map<dynamic>((v) => _deepToJson(v)).toList();
  }
  if (v is num || v is String || v is bool) {
    return v;
  }
  try {
    return _deepToJson(v.toJson());
  } on NoSuchMethodError {
    return v;
  }
}
