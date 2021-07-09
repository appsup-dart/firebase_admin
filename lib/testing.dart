import 'package:firebase_admin/src/credential.dart';
import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_admin/src/testing.dart';

export 'firebase_admin.dart';

extension FirebaseAdminTestingX on FirebaseAdmin {
  Credential testCredentials() {
    return ServiceAccountMockCredential();
  }
}
