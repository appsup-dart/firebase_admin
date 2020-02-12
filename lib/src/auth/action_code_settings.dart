import '../auth.dart';
import '../utils/error.dart';

extension ActionCodeSettingsRequestBuilder on ActionCodeSettings {
  /// Returns the corresponding constructed server request
  Map<String, dynamic> buildRequest() {
    if (url == null) {
      throw FirebaseAuthError.missingContinueUri();
    }

    if (dynamicLinkDomain != null && dynamicLinkDomain.isEmpty) {
      throw FirebaseAuthError.invalidDynamicLinkDomain();
    }

    return {
      'continueUrl': url,
      'canHandleCodeInApp': handleCodeInApp ?? false,
      'dynamicLinkDomain': dynamicLinkDomain,
      'androidPackageName': androidPackageName,
      'androidMinimumVersion': androidMinimumVersion,
      'androidInstallApp': androidInstallApp ?? false,
      'iOSBundleId': iosBundleId,
    }..removeWhere((key, value) => value == null);
  }
}
