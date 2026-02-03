import 'dart:convert';

import 'package:collection/collection.dart';

/// Base class for all Firebase exceptions.
class FirebaseException implements Exception {
  /// Error codes are strings using the following format:
  /// "service/string-code". Some examples include "auth/invalid-uid" and
  /// "messaging/invalid-recipient".
  ///
  /// While the message for a given error can change, the code will remain the
  /// same between backward-compatible versions of the Firebase SDK.
  final String code;

  /// An explanatory message for the error that just occurred.
  ///
  /// This message is designed to be helpful to you, the developer. Because it
  /// generally does not convey meaningful information to end users, this
  /// message should not be displayed in your application.
  final String message;

  const FirebaseException({required this.code, required this.message});

  Map<String, dynamic> toJson() => {'code': code, 'message': message};

  @override
  String toString() => '$runtimeType($code): $message';
}

/// A FirebaseError with a prefix in front of the error code.
class _PrefixedFirebaseError extends FirebaseException {
  final String codePrefix;

  const _PrefixedFirebaseError(this.codePrefix, String code, String message)
      : super(
          code: '$codePrefix/$code',
          message: message,
        );
}

class FirebaseAppError extends _PrefixedFirebaseError {
  FirebaseAppError(String code, String message) : super('app', code, message);

  FirebaseAppError.appDeleted(String message) : this('app-deleted', message);
  FirebaseAppError.duplicateApp(String message)
      : this('duplicate-app', message);
  FirebaseAppError.internalError(String message)
      : this('internal-error', message);
  FirebaseAppError.invalidAppName(String message)
      : this('invalid-app-name', message);
  FirebaseAppError.invalidAppOptions(String message)
      : this('invalid-app-options', message);
  FirebaseAppError.invalidCredential(String message)
      : this('invalid-credential', message);
  FirebaseAppError.networkError(String message)
      : this('network-error', message);
  FirebaseAppError.networkTimeout(String message)
      : this('network-timeout', message);
  FirebaseAppError.noApp(String message) : this('no-app', message);
  FirebaseAppError.unableToParseResponse(String message)
      : this('unable-to-parse-response', message);
}

/// Maps Identity Toolkit API server error codes to FirebaseAuthError instances.
const _serverErrorToAuthError = <String, FirebaseAuthError>{
  'CLAIMS_TOO_LARGE': FirebaseAuthError.claimsTooLarge(),
  'CONFIGURATION_NOT_FOUND': FirebaseAuthError.projectNotFound(),
  'DUPLICATE_EMAIL': FirebaseAuthError.emailAlreadyExists(),
  'DUPLICATE_LOCAL_ID': FirebaseAuthError.uidAlreadyExists(),
  'EMAIL_EXISTS': FirebaseAuthError.emailAlreadyExists(),
  'EMAIL_NOT_FOUND': FirebaseAuthError.emailNotFound(),
  'FORBIDDEN_CLAIM': FirebaseAuthError.forbiddenClaim(),
  'INSUFFICIENT_PERMISSION': FirebaseAuthError.insufficientPermission(),
  'INVALID_CLAIMS': FirebaseAuthError.invalidClaims(),
  'INVALID_CONTINUE_URI': FirebaseAuthError.invalidContinueUri(),
  'INVALID_DURATION': FirebaseAuthError.invalidSessionCookieDuration(),
  'INVALID_DYNAMIC_LINK_DOMAIN': FirebaseAuthError.invalidDynamicLinkDomain(),
  'INVALID_EMAIL': FirebaseAuthError.invalidEmail(),
  'INVALID_ID_TOKEN': FirebaseAuthError.invalidIdToken(),
  'INVALID_PAGE_SELECTION': FirebaseAuthError.invalidPageToken(),
  'INVALID_PHONE_NUMBER': FirebaseAuthError.invalidPhoneNumber(),
  'INVALID_SERVICE_ACCOUNT': FirebaseAuthError.invalidServiceAccount(),
  'MISSING_ANDROID_PACKAGE_NAME': FirebaseAuthError.missingAndroidPackageName(),
  'MISSING_IOS_BUNDLE_ID': FirebaseAuthError.missingIosBundleId(),
  'MISSING_LOCAL_ID': FirebaseAuthError.missingUid(),
  'MISSING_USER_ACCOUNT': FirebaseAuthError.missingUid(),
  'OPERATION_NOT_ALLOWED': FirebaseAuthError.operationNotAllowed(),
  'PERMISSION_DENIED': FirebaseAuthError.insufficientPermission(),
  'PHONE_NUMBER_EXISTS': FirebaseAuthError.phoneNumberAlreadyExists(),
  'PROJECT_NOT_FOUND': FirebaseAuthError.projectNotFound(),
  'TOKEN_EXPIRED': FirebaseAuthError.idTokenExpired(),
  'TOO_MANY_ATTEMPTS_TRY_LATER': FirebaseAuthError.tooManyRequests(),
  'TOO_MANY_REQUESTS': FirebaseAuthError.tooManyRequests(),
  'UNAUTHORIZED_DOMAIN': FirebaseAuthError.unauthorizedDomain(),
  'USER_DISABLED': FirebaseAuthError.userDisabled(),
  'USER_NOT_FOUND': FirebaseAuthError.userNotFound(),
  'UNVERIFIED_EMAIL': FirebaseAuthError.unverifiedEmail(),
  'WEAK_PASSWORD': FirebaseAuthError.invalidPassword(),
};

/// Returns the Identity Toolkit API server error code for the given
/// [FirebaseAuthError], or null if not found.
String? serverCodeForAuthError(String code) => _serverErrorToAuthError.entries
    .firstWhereOrNull((e) => e.value.code == 'auth/$code')
    ?.key;

class FirebaseAuthError extends _PrefixedFirebaseError {
  /// Creates the developer-facing error corresponding to the backend error code.
  factory FirebaseAuthError.fromServerError(
    String serverErrorCode, [
    String? message,
    dynamic rawServerResponse,
  ]) {
    // serverErrorCode could contain additional details:
    // ERROR_CODE : Detailed message which can also contain colons
    final colonSeparator = serverErrorCode.indexOf(':');
    String? customMessage;
    if (colonSeparator != -1) {
      customMessage = serverErrorCode.substring(colonSeparator + 1).trim();
      serverErrorCode = serverErrorCode.substring(0, colonSeparator).trim();
    }

    customMessage ??= message;

    final error = _serverErrorToAuthError[serverErrorCode];
    if (error != null) {
      final shortCode = error.code.substring(5); // 'auth/'.length
      return FirebaseAuthError(shortCode, customMessage ?? error.message);
    }
    return FirebaseAuthError.internalError(customMessage, rawServerResponse);
  }

  /// The claims payload provided to [setCustomUserClaims] exceeds the maximum
  /// allowed size of 1000 bytes.
  const FirebaseAuthError.claimsTooLarge([String? message])
      : this('claims-too-large',
            message ?? 'Developer claims maximum payload size exceeded.');

  /// The provided email is already in use by an existing user. Each user must
  /// have a unique email.
  const FirebaseAuthError.emailAlreadyExists([String? message])
      : this(
            'email-already-exists',
            message ??
                'The email address is already in use by another account.');

  /// There is no user record corresponding to the provided email.
  const FirebaseAuthError.emailNotFound([String? message])
      : this(
            'email-not-found',
            message ??
                'There is no user record corresponding to the provided email.');

  /// The provided Firebase ID token is expired.
  const FirebaseAuthError.idTokenExpired([String? message])
      : this('id-token-expired',
            message ?? 'The provided Firebase ID token is expired.');

  /// The Firebase ID token has been revoked.
  const FirebaseAuthError.idTokenRevoked([String? message])
      : this('id-token-revoked',
            message ?? 'The Firebase ID token has been revoked.');

  /// The credential used to initialize the Admin SDK has insufficient
  /// permission to access the requested Authentication resource.
  ///
  /// Refer to Set up a Firebase project for documentation on how to generate a
  /// credential with appropriate permissions and use it to authenticate the
  /// Admin SDKs.
  const FirebaseAuthError.insufficientPermission([String? message])
      : this(
            'insufficient-permission',
            message ??
                'Credential implementation provided to initializeApp() via the '
                    '"credential" property has insufficient permission to '
                    'access the requested resource. See '
                    'https://firebase.google.com/docs/admin/setup for details '
                    'on how to authenticate this SDK with appropriate '
                    'permissions.');

  /// The Authentication server encountered an unexpected error while trying to
  /// process the request.
  ///
  /// The error message should contain the response from the Authentication
  /// server containing additional information. If the error persists, please
  /// report the problem to our Bug Report support channel.
  // Cannot be const: uses json.encode(rawServerResponse) at runtime.
  FirebaseAuthError.internalError([String? message, rawServerResponse])
      : this('internal-error',
            '${message ?? 'An internal error has occurred.'}Raw server response: "${json.encode(rawServerResponse)}"');

  /// An invalid argument was provided to an Authentication method.
  ///
  /// The error message should contain additional information.
  const FirebaseAuthError.invalidArgument([String? message])
      : this('argument-error', message ?? 'Invalid argument provided.');

  /// The custom claim attributes provided to setCustomUserClaims() are invalid.
  const FirebaseAuthError.invalidClaims([String? message])
      : this('invalid-claims',
            message ?? 'The provided custom claim attributes are invalid.');

  /// The continue URL must be a valid URL string.
  const FirebaseAuthError.invalidContinueUri([String? message])
      : this('invalid-continue-uri',
            message ?? 'The continue URL must be a valid URL string.');

  /// The creation time must be a valid UTC date string.
  const FirebaseAuthError.invalidCreationTime([String? message])
      : this('invalid-creation-time',
            message ?? 'The creation time must be a valid UTC date string.');

  /// The credential used to authenticate the Admin SDKs cannot be used to
  /// perform the desired action.
  ///
  /// Certain Authentication methods such as [createCustomToken] and
  /// [verifyIdToken] require the SDK to be initialized with a certificate
  /// credential as opposed to a refresh token or Application Default
  /// credential.
  ///
  /// See Initialize the SDK for documentation on how to authenticate the Admin
  /// SDKs with a certificate credential.
  const FirebaseAuthError.invalidCredential([String? message])
      : this('invalid-credential',
            message ?? 'Invalid credential object provided.');

  /// The provided value for the disabled user property is invalid. It must be a
  /// boolean.
  const FirebaseAuthError.invalidDisabledField([String? message])
      : this('invalid-disabled-field',
            message ?? 'The disabled field must be a boolean.');

  /// The provided value for the displayName user property is invalid. It must
  /// be a non-empty string.
  const FirebaseAuthError.invalidDisplayName([String? message])
      : this('invalid-display-name',
            message ?? 'The displayName field must be a valid string.');

  /// The provided dynamic link domain is not configured or authorized for the
  /// current project.
  const FirebaseAuthError.invalidDynamicLinkDomain([String? message])
      : this(
            'invalid-dynamic-link-domain',
            message ??
                'The provided dynamic link domain is not configured or authorized '
                    'for the current project.');

  /// The provided value for the email user property is invalid. It must be a
  /// string email address.
  const FirebaseAuthError.invalidEmail([String? message])
      : this('invalid-email',
            message ?? 'The email address is improperly formatted.');

  /// The provided value for the emailVerified user property is invalid. It must
  /// be a boolean.
  const FirebaseAuthError.invalidEmailVerified([String? message])
      : this('invalid-email-verified',
            message ?? 'The emailVerified field must be a boolean.');

  /// The hash algorithm must match one of the strings in the list of supported
  /// algorithms.
  const FirebaseAuthError.invalidHashAlgorithm([String? message])
      : this(
            'invalid-hash-algorithm',
            message ??
                'The hash algorithm must match one of the strings in the list of '
                    'supported algorithms.');

  /// The hash block size must be a valid number.
  const FirebaseAuthError.invalidHashBlockSize([String? message])
      : this('invalid-hash-block-size',
            message ?? 'The hash block size must be a valid number.');

  /// The hash derived key length must be a valid number.
  const FirebaseAuthError.invalidHashDerivedKeyLength([String? message])
      : this('invalid-hash-derived-key-length',
            message ?? 'The hash derived key length must be a valid number.');

  /// The hash key must a valid byte buffer.
  const FirebaseAuthError.invalidHashKey([String? message])
      : this('invalid-hash-key',
            message ?? 'The hash key must a valid byte buffer.');

  /// The hash memory cost must be a valid number.
  const FirebaseAuthError.invalidHashMemoryCost([String? message])
      : this('invalid-hash-memory-cost',
            message ?? 'The hash memory cost must be a valid number.');

  /// The hash parallelization must be a valid number.
  const FirebaseAuthError.invalidHashParallelization([String? message])
      : this('invalid-hash-parallelization',
            message ?? 'The hash parallelization must be a valid number.');

  /// The hash rounds must be a valid number.
  const FirebaseAuthError.invalidHashRounds([String? message])
      : this('invalid-hash-rounds',
            message ?? 'The hash rounds must be a valid number.');

  /// The hashing algorithm salt separator field must be a valid byte buffer.
  const FirebaseAuthError.invalidHashSaltSeparator([String? message])
      : this(
            'invalid-hash-salt-separator',
            message ??
                'The hashing algorithm salt separator field must be a valid byte buffer.');

  /// The provided ID token is not a valid Firebase ID token.
  const FirebaseAuthError.invalidIdToken([String? message])
      : this(
            'invalid-id-token',
            message ??
                'The provided ID token is not a valid Firebase ID token.');

  /// The last sign-in time must be a valid UTC date string.
  const FirebaseAuthError.invalidLastSignInTime([String? message])
      : this(
            'invalid-last-sign-in-time',
            message ??
                'The last sign-in time must be a valid UTC date string.');

  /// The provided next page token in listUsers() is invalid. It must be a valid
  /// non-empty string.
  const FirebaseAuthError.invalidPageToken([String? message])
      : this('invalid-page-token',
            message ?? 'The page token must be a valid non-empty string.');

  /// The provided value for the password user property is invalid. It must be a
  /// string with at least six characters.
  const FirebaseAuthError.invalidPassword([String? message])
      : this(
            'invalid-password',
            message ??
                'The password must be a string with at least 6 characters.');

  /// The password hash must be a valid byte buffer.
  const FirebaseAuthError.invalidPasswordHash([String? message])
      : this('invalid-password-hash',
            message ?? 'The password hash must be a valid byte buffer.');

  /// The password salt must be a valid byte buffer
  const FirebaseAuthError.invalidPasswordSalt([String? message])
      : this('invalid-password-salt',
            message ?? 'The password salt must be a valid byte buffer.');

  /// The provided value for the phoneNumber is invalid. It must be a non-empty
  /// E.164 standard compliant identifier string.
  const FirebaseAuthError.invalidPhoneNumber([String? message])
      : this(
            'invalid-phone-number',
            message ??
                'The phone number must be a non-empty E.164 standard compliant identifier '
                    'string.');

  /// Invalid service account.
  const FirebaseAuthError.invalidServiceAccount([String? message])
      : this('invalid-service-account', message ?? 'Invalid service account.');

  /// The provided value for the photoURL user property is invalid. It must be a
  /// string URL.
  const FirebaseAuthError.invalidPhotoUrl([String? message])
      : this('invalid-photo-url',
            message ?? 'The photoURL field must be a valid URL.');

  /// The providerData must be a valid array of UserInfo objects.
  const FirebaseAuthError.invalidProviderData([String? message])
      : this(
            'invalid-provider-data',
            message ??
                'The providerData must be a valid array of UserInfo objects.');

  /// The providerId must be a valid supported provider identifier string.
  const FirebaseAuthError.invalidProviderId([String? message])
      : this(
            'invalid-provider-id',
            message ??
                'The providerId must be a valid supported provider identifier string.');

  /// The session cookie duration must be a valid number in milliseconds between
  /// 5 minutes and 2 weeks.
  const FirebaseAuthError.invalidSessionCookieDuration([String? message])
      : this(
            'invalid-session-cookie-duration',
            message ??
                'The session cookie duration must be a valid number in milliseconds '
                    'between 5 minutes and 2 weeks.');

  /// The provided uid must be a non-empty string with at most 128 characters.
  const FirebaseAuthError.invalidUid([String? message])
      : this(
            'invalid-uid',
            message ??
                'The uid must be a non-empty string with at most 128 characters.');

  /// The user record to import is invalid.
  const FirebaseAuthError.invalidUserImport([String? message])
      : this('invalid-user-import',
            message ?? 'The user record to import is invalid.');

  /// The maximum allowed number of users to import has been exceeded.
  const FirebaseAuthError.maximumUserCountExceeded([String? message])
      : this(
            'maximum-user-count-exceeded',
            message ??
                'The maximum allowed number of users to import has been exceeded.');

  /// An Android Package Name must be provided if the Android App is required to
  /// be installed.
  const FirebaseAuthError.missingAndroidPackageName([String? message])
      : this(
            'missing-android-pkg-name',
            message ??
                'An Android Package Name must be provided if the Android App is '
                    'required to be installed.');

  /// A valid continue URL must be provided in the request.
  const FirebaseAuthError.missingContinueUri([String? message])
      : this('missing-continue-uri',
            message ?? 'A valid continue URL must be provided in the request.');

  /// Importing users with password hashes requires that the hashing algorithm
  /// and its parameters be provided.
  const FirebaseAuthError.missingHashAlgorithm([String? message])
      : this(
            'missing-hash-algorithm',
            message ??
                'Importing users with password hashes requires that the hashing '
                    'algorithm and its parameters be provided.');

  /// The request is missing an iOS Bundle ID.
  const FirebaseAuthError.missingIosBundleId([String? message])
      : this('missing-ios-bundle-id',
            message ?? 'The request is missing an iOS Bundle ID.');

  /// A uid identifier is required for the current operation.
  const FirebaseAuthError.missingUid([String? message])
      : this(
            'missing-uid',
            message ??
                'A uid identifier is required for the current operation.');

  /// The provided sign-in provider is disabled for your Firebase project.
  ///
  /// Enable it from the Sign-in Method section of the Firebase console.
  const FirebaseAuthError.operationNotAllowed([String? message])
      : this(
            'operation-not-allowed',
            message ??
                'The given sign-in provider is disabled for this Firebase project. '
                    'Enable it in the Firebase console, under the sign-in method tab of the '
                    'Auth section.');

  /// The provided phoneNumber is already in use by an existing user. Each user
  /// must have a unique phoneNumber.
  const FirebaseAuthError.phoneNumberAlreadyExists([String? message])
      : this(
            'phone-number-already-exists',
            message ??
                'The user with the provided phone number already exists.');

  /// No Firebase project was found for the credential used to initialize the
  /// Admin SDKs.
  ///
  /// Refer to Set up a Firebase project for documentation on how to generate a
  /// credential for your project and use it to authenticate the Admin SDKs.
  const FirebaseAuthError.projectNotFound([String? message])
      : this(
            'project-not-found',
            message ??
                'No Firebase project was found for the provided credential.');

  /// One or more custom user claims provided to setCustomUserClaims() are
  /// reserved.
  ///
  /// For example, OIDC specific claims such as (sub, iat, iss, exp, aud,
  /// auth_time, etc) should not be used as keys for custom claims.
  const FirebaseAuthError.forbiddenClaim([String? message])
      : this(
            'reserved-claim',
            message ??
                'The specified developer claim is reserved and cannot be specified.');

  /// The provided Firebase session cookie is expired.
  const FirebaseAuthError.sessionCookieExpired([String? message])
      : this('session-cookie-expired',
            message ?? 'The Firebase session cookie is expired.');

  /// The Firebase session cookie has been revoked.
  const FirebaseAuthError.sessionCookieRevoked([String? message])
      : this('session-cookie-revoked',
            message ?? 'The Firebase session cookie has been revoked.');

  /// The provided uid is already in use by an existing user. Each user must
  /// have a unique uid.
  const FirebaseAuthError.uidAlreadyExists([String? message])
      : this('uid-already-exists',
            message ?? 'The user with the provided uid already exists.');

  /// The domain of the continue URL is not whitelisted. Whitelist the domain in
  /// the Firebase Console.
  const FirebaseAuthError.unauthorizedDomain([String? message])
      : this(
            'unauthorized-continue-uri',
            message ??
                'The domain of the continue URL is not whitelisted. Whitelist the domain in the '
                    'Firebase console.');

  /// There is no existing user record corresponding to the provided identifier.
  const FirebaseAuthError.userNotFound([String? message])
      : this(
            'user-not-found',
            message ??
                'There is no user record corresponding to the provided identifier.');

  /// The user account has been disabled by an administrator.
  const FirebaseAuthError.userDisabled([String? message])
      : this(
            'user-disabled',
            message ??
                'The user account has been disabled by an administrator.');

  /// The email address has not been verified.
  const FirebaseAuthError.unverifiedEmail([String? message])
      : this('unverified-email',
            message ?? 'The email address has not been verified.');

  /// The number of requests exceeds the maximum allowed.
  const FirebaseAuthError.tooManyRequests([String? message])
      : this('too-many-requests',
            message ?? 'The number of requests exceeds the maximum allowed.');

  const FirebaseAuthError.quotaExceeded([String? message])
      : this(
            'quota-exceeded',
            message ??
                'The project quota for the specified operation has been exceeded.');
  const FirebaseAuthError.tenantNotFound([String? message])
      : this(
            'tenant-not-found',
            message ??
                'There is no tenant corresponding to the provided identifier.');
  const FirebaseAuthError.unsupportedTenantOperation([String? message])
      : this(
            'unsupported-tenant-operation',
            message ??
                'This operation is not supported in a multi-tenant context.');
  const FirebaseAuthError.missingDisplayName([String? message])
      : this(
            'missing-display-name',
            message ??
                'The resource being created or edited is missing a valid display name.');
  const FirebaseAuthError.missingIssuer([String? message])
      : this(
            'missing-issuer',
            message ??
                'The OAuth/OIDC configuration issuer must not be empty.');
  const FirebaseAuthError.missingOAuthClientId([String? message])
      : this(
            'missing-oauth-client-id',
            message ??
                'The OAuth/OIDC configuration client ID must not be empty.');
  const FirebaseAuthError.missingProviderId([String? message])
      : this('missing-provider-id',
            message ?? 'A valid provider ID must be provided in the request.');
  const FirebaseAuthError.missingSamlRelyingPartyConfig([String? message])
      : this(
            'missing-saml-relying-party-config',
            message ??
                'The SAML configuration provided is missing a relying party configuration.');
  //
  ///
  const FirebaseAuthError.missingConfig([String? message])
      : this(
            'missing-config',
            message ??
                'The provided configuration is missing required attributes.');
  const FirebaseAuthError.invalidTokensValidAfterTime([String? message])
      : this(
            'invalid-tokens-valid-after-time',
            message ??
                'The tokensValidAfterTime must be a valid UTC number in seconds.');

  const FirebaseAuthError.invalidTenantId([String? message])
      : this('invalid-tenant-id',
            message ?? 'The tenant ID must be a valid non-empty string.');
  const FirebaseAuthError.invalidTenantType([String? message])
      : this(
            'invalid-tenant-type',
            message ??
                'Tenant type must be either "full_service" or "lightweight".');

  const FirebaseAuthError.invalidProjectId([String? message])
      : this(
            'invalid-project-id',
            message ??
                'Invalid parent project. Either parent project doesn\'t exist or didn\'t enable multi-tenancy.');
  const FirebaseAuthError.invalidName([String? message])
      : this('invalid-name',
            message ?? 'The resource name provided is invalid.');
  const FirebaseAuthError.invalidOAuthClientId([String? message])
      : this('invalid-oauth-client-id',
            message ?? 'The provided OAuth client ID is invalid.');
  //

  const FirebaseAuthError.billingNotEnabled([String? message])
      : this('billing-not-enabled',
            message ?? 'Feature requires billing to be enabled.');

  const FirebaseAuthError.configurationExists([String? message])
      : this(
            'configuration-exists',
            message ??
                'A configuration already exists with the provided identifier.');
  const FirebaseAuthError.configurationNotFound([String? message])
      : this(
            'configuration-not-found',
            message ??
                'There is no configuration corresponding to the provided identifier.');

  const FirebaseAuthError.invalidConfigs([String? message])
      : this('invalid-config',
            message ?? 'The provided configuration is invalid.');
  const FirebaseAuthError.mismatchingTenantId([String? message])
      : this(
            'mismatching-tenant-id',
            message ??
                'User tenant ID does not match with the current TenantAwareAuth tenant ID.');
  const FirebaseAuthError.notFound([String? message])
      : this('not-found', message ?? 'The requested resource was not found.');

  const FirebaseAuthError(String code, String message)
      : super('auth', code, message);
}

class FirebaseStorageError extends _PrefixedFirebaseError {
  FirebaseStorageError(String code, String message)
      : super('storage', code, message);

  FirebaseStorageError.invalidArgument(String message)
      : this('invalid-argument', message);
}
