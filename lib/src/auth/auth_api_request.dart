import 'dart:convert';

import 'package:clock/clock.dart';

import '../auth.dart';
import '../app/app_extension.dart';
import '../utils/api_request.dart';
import '../utils/error.dart';

import '../app.dart';
import 'action_code_settings.dart';
import '../utils/validator.dart' as validator;
import 'package:http/http.dart';

import 'package:collection/collection.dart';

class ApiClient {
  final Client httpClient;

  final String baseUrl;

  /// Firebase Auth request header.
  static const _firebaseAuthHeader = {
    'X-Client-Version': 'Dart/Admin/<XXX_SDK_VERSION_XXX>',
  };

  /// Firebase Auth request timeout duration in milliseconds.
  static const _firebaseAuthTimeout = Duration(milliseconds: 25000);

  ApiClient(App app, String version, String? projectId)
      : httpClient = AuthorizedHttpClient(app, _firebaseAuthTimeout),
        baseUrl =
            'https://identitytoolkit.googleapis.com/$version/projects/$projectId';

  Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> body) async {
    var response = await httpClient.post(Uri.parse('$baseUrl$endpoint'),
        body: json.encode(body), headers: _firebaseAuthHeader);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> get(
      String endpoint, Map<String, dynamic> body) async {
    var response = await httpClient.get(
        Uri.parse('$baseUrl$endpoint').replace(queryParameters: body),
        headers: _firebaseAuthHeader);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(Response response) {
    var data = json.decode(response.body);
    if (response.statusCode < 300) {
      return data;
    }

    final errorCode = (data['error'] ?? {})['message'];
    if (errorCode == null) {
      throw FirebaseAuthError.internalError(
          'An internal error occurred while attempting to extract the '
          'errorcode from the error.',
          data);
    }
    throw FirebaseAuthError.fromServerError(errorCode, null, data);
  }
}

class AuthRequestHandler {
  final ApiClient apiClient;

  static AuthRequestHandler Function(App app) factory =
      (app) => AuthRequestHandler._(app);

  factory AuthRequestHandler(App app) => factory(app);
  AuthRequestHandler._(App app)
      : apiClient = ApiClient(app, 'v1', app.projectId);

  /// Maximum allowed number of users to batch download at one time.
  static const maxDownloadAccountPageSize = 1000;

  /// Looks up a user by uid.
  Future<Map<String, dynamic>> getAccountInfoByUid(String uid) async {
    if (!validator.isUid(uid)) {
      throw FirebaseAuthError.invalidUid();
    }
    return _getAccountInfo({
      'localId': [uid],
    });
  }

  /// Looks up a user by email.
  Future<Map<String, dynamic>> getAccountInfoByEmail(String email) async {
    if (!validator.isEmail(email)) {
      throw FirebaseAuthError.invalidEmail();
    }
    return _getAccountInfo({
      'email': [email],
    });
  }

  /// Looks up a user by phone number.
  Future<Map<String, dynamic>> getAccountInfoByPhoneNumber(
      String phoneNumber) async {
    if (!validator.isPhoneNumber(phoneNumber)) {
      throw FirebaseAuthError.invalidPhoneNumber();
    }
    return _getAccountInfo({
      'phoneNumber': [phoneNumber],
    });
  }

  Future<Map<String, dynamic>> _getAccountInfo(
      Map<String, dynamic> request) async {
    var response = await apiClient.post('/accounts:lookup', request);

    if (!response.containsKey('users')) {
      throw FirebaseAuthError.userNotFound();
    }

    return response;
  }

  /// Exports the users (single batch only) with a size of maxResults and
  /// starting from the offset as specified by pageToken.
  Future<Map<String, dynamic>> downloadAccount(
      int? maxResults, String? pageToken) async {
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

    // Construct request.
    var request = {
      'maxResults': '$maxResults',
      if (pageToken != null) 'nextPageToken': pageToken,
    };

    return await apiClient.get('/accounts:batchGet', request);
  }

  /// Create a new user with the properties supplied.
  Future<String> createNewAccount(CreateEditAccountRequest request) async {
    var response = await apiClient.post('/accounts', request.toRequest());

    // If the localId is not returned, then the request failed.
    if (response['localId'] == null) {
      throw FirebaseAuthError.internalError(
          'INTERNAL ASSERT FAILED: Unable to create new user');
    }

    return response['localId'];
  }

  /// Deletes an account identified by a uid.
  Future<Map<String, dynamic>> deleteAccount(String uid) {
    if (!validator.isUid(uid)) {
      throw FirebaseAuthError.invalidUid();
    }

    final request = {
      'localId': uid,
    };

    return apiClient.post('/accounts:delete', request);
  }

  /// Edits an existing user.
  Future<String> updateExistingAccount(
      String uid, CreateEditAccountRequest request) async {
    if (!validator.isUid(uid)) {
      throw FirebaseAuthError.invalidUid();
    }

    return _setAccountInfo(request);
  }

  /// Sets additional developer claims on an existing user identified by
  /// provided UID.
  Future<String> setCustomUserClaims(
      String uid, Map<String, dynamic>? customUserClaims) async {
    // Validate user UID.
    if (!validator.isUid(uid)) {
      throw FirebaseAuthError.invalidUid();
    }

    // Delete operation. Replace null with an empty object.
    customUserClaims ??= {};

    return _setAccountInfo(
        CreateEditAccountRequest(uid: uid, customAttributes: customUserClaims));
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
  Future<String> revokeRefreshTokens(String uid) async {
    // Validate user UID.
    if (!validator.isUid(uid)) {
      throw FirebaseAuthError.invalidUid();
    }
    return await _setAccountInfo(
        CreateEditAccountRequest(uid: uid, validSince: clock.now()));
  }

  Future<String> _setAccountInfo(CreateEditAccountRequest request) async {
    var response =
        await apiClient.post('/accounts:update', request.toRequest());

    // If the localId is not returned, then the request failed.
    if (response['localId'] == null) {
      throw FirebaseAuthError.userNotFound();
    }

    return response['localId'];
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
      {ActionCodeSettings? actionCodeSettings}) async {
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

    var request = {
      'requestType': requestType,
      'email': email,
      'returnOobLink': true
    };
    // ActionCodeSettings required for email link sign-in to determine the url where the sign-in will
    // be completed.
    if (actionCodeSettings == null && requestType == 'EMAIL_SIGNIN') {
      throw FirebaseAuthError.invalidArgument(
        "`actionCodeSettings` is required when `requestType` == 'EMAIL_SIGNIN'",
      );
    }
    if (actionCodeSettings != null || requestType == 'EMAIL_SIGNIN') {
      request = {
        ...request,
        ...actionCodeSettings!.buildRequest(),
      };
    }
    var response = await apiClient.post('/accounts:sendOobCode', request);

    // If the oobLink is not returned, then the request failed.
    if (response['oobLink'] == null) {
      throw FirebaseAuthError.internalError(
          'INTERNAL ASSERT FAILED: Unable to create the email action link');
    }

    // Return the link.
    return response['oobLink'];
  }
}

class UploadAccountRequest extends CreateEditAccountRequest {}

class CreateEditAccountRequest {
  final bool? disabled;
  final String? displayName;
  final String? email;
  final bool? emailVerified;
  final String? password;
  final String? phoneNumber;
  final String? photoUrl;
  final String? uid;
  final String? customAttributes;
  final DateTime? validSince;

  static const _reservedClaims = [
    'acr',
    'amr',
    'at_hash',
    'aud',
    'auth_time',
    'azp',
    'cnf',
    'c_hash',
    'exp',
    'iat',
    'iss',
    'jti',
    'nbf',
    'nonce',
    'sub',
    'firebase',
  ];

  /// Maximum allowed number of characters in the custom claims payload.
  static const _maxClaimsPayloadSize = 1000;

  static String _stringifyClaims(Map<String, dynamic> claims) {
    // customAttributes should be stringified JSON with no blacklisted claims.
    // The payload should not exceed 1KB.

    // Check for any invalid claims.
    var invalidClaims = claims.keys.where((v) => _reservedClaims.contains(v));
    // Throw an error if an invalid claim is detected.
    if (invalidClaims.isNotEmpty) {
      throw FirebaseAuthError.forbiddenClaim(
        invalidClaims.length > 1
            ? 'Developer claims "${invalidClaims.join('", "')}" are reserved and cannot be specified.'
            : 'Developer claim "${invalidClaims.first}" is reserved and cannot be specified.',
      );
    }

    var s = json.encode(claims);
    // Check claims payload does not exceed maxmimum size.
    if (s.length > _maxClaimsPayloadSize) {
      throw FirebaseAuthError.claimsTooLarge(
        'Developer claims payload should not exceed $_maxClaimsPayloadSize characters.',
      );
    }

    return s;
  }

  CreateEditAccountRequest(
      {this.disabled,
      this.displayName,
      this.email,
      this.emailVerified,
      this.password,
      this.phoneNumber,
      this.photoUrl,
      this.uid,
      this.validSince,
      Map<String, dynamic>? customAttributes})
      : customAttributes = customAttributes == null
            ? null
            : _stringifyClaims(customAttributes) {
    if (disabled == null &&
        displayName == null &&
        email == null &&
        emailVerified == null &&
        password == null &&
        phoneNumber == null &&
        photoUrl == null &&
        customAttributes == null &&
        validSince == null) {
      throw FirebaseAuthError.invalidArgument();
    }

    if ((uid != null || this is UploadAccountRequest) &&
        !validator.isUid(uid)) {
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
    // rawPassword should be a string and a minimum of 6 chars.
/*TODO
    if (rawPassword != null && !validator.isPassword(rawPassword)) {
      // This is called rawPassword on the backend but the developer specifies this as
      // password externally. So the error message should use the client facing name.
      throw FirebaseAuthError.invalidPassword();
    }
*/
    // photoUrl should be a URL.
    if (photoUrl != null && !validator.isUrl(photoUrl)) {
      // This is called photoUrl on the backend but the developer specifies this as
      // photoURL externally. So the error message should use the client facing name.
      throw FirebaseAuthError.invalidPhotoUrl();
    }

    // createdAt should be a number.
/* TODO
    if (typeof request.createdAt !== 'undefined' &&
    !validator.isNumber(request.createdAt)) {
    throw new FirebaseAuthError(AuthClientErrorCode.INVALID_CREATION_TIME);
    }
*/
    // lastSignInAt should be a number.
/* TODO
    if (typeof request.lastLoginAt !== 'undefined' &&
    !validator.isNumber(request.lastLoginAt)) {
    throw new FirebaseAuthError(AuthClientErrorCode.INVALID_LAST_SIGN_IN_TIME);
    }
*/

    // passwordHash has to be a base64 encoded string.
/* TODO
    if (passwordHash!=null &&
    !validator.isString(request.passwordHash)) {
    throw new FirebaseAuthError(AuthClientErrorCode.INVALID_PASSWORD_HASH);
    }
*/
    // salt has to be a base64 encoded string.
/*TODO
    if (typeof request.salt !== 'undefined' &&
    !validator.isString(request.salt)) {
    throw new FirebaseAuthError(AuthClientErrorCode.INVALID_PASSWORD_SALT);
    }
*/
    // providerUserInfo has to be an array of valid UserInfo requests.
    /*TODO
  if (typeof request.providerUserInfo !== 'undefined' &&
      !validator.isArray(request.providerUserInfo)) {
    throw new FirebaseAuthError(AuthClientErrorCode.INVALID_PROVIDER_DATA);
  } else if (validator.isArray(request.providerUserInfo)) {
    request.providerUserInfo.forEach((providerUserInfoEntry: any) => {
      validateProviderUserInfo(providerUserInfoEntry);
    });
  }
     */
  }

  Map<String, dynamic> toRequest() => {
        'disabled': disabled,
        if (displayName != '') 'displayName': displayName,
        'email': email,
        'emailVerified': emailVerified,
        'password': password,
        if (phoneNumber != '') 'phoneNumber': phoneNumber,
        if (photoUrl != '') 'photoUrl': photoUrl,
        'localId': uid,
        // For deleting displayName or photoURL, these values must be passed as null.
        // They will be removed from the backend request and an additional parameter
        // deleteAttribute: ['PHOTO_URL', 'DISPLAY_NAME']
        // with an array of the parameter names to delete will be passed.
        'deleteAttribute': [
          if (displayName == '') 'DISPLAY_NAME',
          if (photoUrl == '') 'PHOTO_URL'
        ],
        // For deleting phoneNumber, this value must be passed as null.
        // It will be removed from the backend request and an additional parameter
        // deleteProvider: ['phone'] with an array of providerIds (phone in this case),
        // will be passed.
        // Currently this applies to phone provider only.
        if (phoneNumber == '') 'deleteProvider': ['phone'],
        if (validSince != null)
          'validSince': validSince!.millisecondsSinceEpoch ~/ 1000
      };

  @override
  int get hashCode => const DeepCollectionEquality().hash(toRequest());

  @override
  bool operator ==(other) =>
      other is CreateEditAccountRequest &&
      const DeepCollectionEquality().equals(toRequest(), other.toRequest());
}
