

import 'package:firebase_admin/firebase_admin.dart';
import 'package:test/test.dart';
import 'resources/mocks.dart' as mocks;

Matcher throwsFirebaseError([String? code]) => throwsA(
    TypeMatcher<FirebaseException>().having((e) => e.code, 'code', code));

void main() {
  var admin = FirebaseAdmin.instance;
  group('Storage', () {
    var mockApp = admin.initializeApp(mocks.appOptions, mocks.appName);
    var storage = mockApp.storage();

    test('bucket("") should throw', () {
      expect(() => storage.bucket(''),
          throwsFirebaseError('storage/invalid-argument'));
    });
    test('bucket() should return a bucket object', () {
      expect(storage.bucket().bucketName, 'bucketName.appspot.com');
    });
    test('bucket("foo") should return a bucket object', () {
      expect(storage.bucket('foo').bucketName, 'foo');
    });
  });
}
