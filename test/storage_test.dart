import 'package:firebase_admin/firebase_admin.dart';
import 'package:test/test.dart';
import 'resources/mocks.dart' as mocks;

Matcher throwsFirebaseError([String? code]) => throwsA(
  TypeMatcher<FirebaseException>().having((e) => e.code, 'code', code),
);

void main() {
  var admin = FirebaseAdmin.instance;
  group('Storage', () {
    var mockApp = admin.initializeApp(mocks.appOptions, mocks.appName);
    var storage = mockApp.storage();

    test('bucket("") should throw', () {
      expect(
        () => storage.bucket(''),
        throwsFirebaseError('storage/invalid-argument'),
      );
    });
    test('bucket() should return a bucket object', () {
      expect(storage.bucket(), isA<Bucket>());
      expect(storage.bucket().name, 'bucketName.appspot.com');
    });
    test('bucket("foo") should return a bucket object', () {
      expect(storage.bucket('foo').name, 'foo');
    });
    test('file() returns an object reference with delimiter', () {
      final file = storage.bucket('foo').file('path/to/obj.txt');
      expect(file, isA<File>());
      expect(file, isA<BucketItem>());
      expect(file.bucket.name, 'foo');
      expect(file.name, 'path/to/obj.txt');
      expect(file.delimiter, '/');
      expect(file.isObject, isTrue);
      expect(file.isDirectory, isFalse);
    });
    test('prefix() and root() create Prefix refs', () {
      final root = storage.bucket('foo').root();
      expect(root, isA<Prefix>());
      expect(root.name, isEmpty);
      expect(root.delimiter, '/');
      expect(root.isDirectory, isTrue);
      expect(root.parent, isNull);

      final docs = storage.bucket('foo').prefix('docs/');
      expect(docs.name, 'docs/');
      expect(docs.delimiter, '/');
      expect(docs.parent!.name, isEmpty);

      final nested = storage.bucket('foo').prefix('docs/images/');
      expect(nested.parent!.name, 'docs/');

      final dotted = storage.bucket('foo').prefix('a.b.', delimiter: '.');
      expect(dotted.delimiter, '.');
      expect(dotted.parent!.name, 'a.');
    });
    test('File.parent walks the delimiter hierarchy', () {
      final file = storage.bucket('foo').file('docs/images/a.png');
      expect(file.parent!.name, 'docs/images/');
      expect(file.parent!.parent!.name, 'docs/');
      expect(file.parent!.parent!.parent!.name, isEmpty);
      expect(file.parent!.parent!.parent!.parent, isNull);

      final top = storage.bucket('foo').file('readme.txt');
      expect(top.parent!.name, isEmpty);
    });
    test('absoluteObjectName() includes gs scheme', () {
      expect(storage.bucket('foo').absoluteObjectName('a/b'), 'gs://foo/a/b');
    });
  });
}
