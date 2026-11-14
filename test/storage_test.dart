import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_admin/src/utils/api_request.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  group('Storage write', () {
    late http.Client Function() previousFactory;
    late App app;
    late Storage storage;
    http.BaseRequest? lastRequest;

    setUp(() {
      previousFactory = AuthorizedHttpClient.httpClientFactory;
      lastRequest = null;
      AuthorizedHttpClient.httpClientFactory = () => MockClient((
        request,
      ) async {
        lastRequest = request;
        final name = request.url.queryParameters['name'] ?? 'uploaded.txt';
        return http.Response(
          jsonEncode({
            'kind': 'storage#object',
            'bucket': 'upload-bucket',
            'name': name,
            'contentType': 'text/plain',
            'size': '5',
            'generation': '42',
            'metadata': {'env': 'test'},
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      app = admin.initializeApp(
        mocks.appOptions,
        'storage-write-${DateTime.now().microsecondsSinceEpoch}',
      );
      storage = app.storage();
    });

    tearDown(() async {
      AuthorizedHttpClient.httpClientFactory = previousFactory;
      await app.delete();
    });

    test('File.writeBytes uploads bytes and returns ObjectInfo', () async {
      final info = await storage
          .bucket('upload-bucket')
          .file('docs/a.txt')
          .writeBytes(
            utf8.encode('hello'),
            contentType: 'text/plain',
            metadata: {'env': 'test'},
          );
      expect(info, isA<ObjectInfo>());
      expect(info.bucket, 'upload-bucket');
      expect(info.name, 'docs/a.txt');
      expect(info.contentType, 'text/plain');
      expect(info.length, 5);
      expect(info.generation, '42');
      expect(info.customMetadata, {'env': 'test'});
      expect(lastRequest, isNotNull);
      expect(lastRequest!.method, 'POST');
      expect(lastRequest!.url.path, contains('/upload/storage/v1/b/'));
      expect(lastRequest!.url.path, contains('/upload-bucket/o'));
    });


    test('File.write sink uploads on close', () async {
      final sink = storage.bucket('upload-bucket').file('docs/c.txt').write(
        length: 5,
        contentType: 'text/plain',
      );
      sink.add(utf8.encode('hello'));
      final info = await sink.close();
      expect(info.name, 'docs/c.txt');
      expect(info.length, 5);
    });
  });

  group('Storage read', () {
    late http.Client Function() previousFactory;
    late App app;
    late Storage storage;

    setUp(() {
      previousFactory = AuthorizedHttpClient.httpClientFactory;
      AuthorizedHttpClient.httpClientFactory = () => MockClient((
        request,
      ) async {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['alt'], 'media');
        final bytes = utf8.encode('hello');
        final range = request.headers['range'];
        if (range != null) {
          // bytes=1-3 → "ell"
          expect(range, 'bytes=1-3');
          return http.Response.bytes(
            bytes.sublist(1, 4),
            206,
            headers: {
              'content-type': 'text/plain',
              'content-length': '3',
              'content-range': 'bytes 1-3/5',
            },
            request: request,
          );
        }
        return http.Response.bytes(
          bytes,
          200,
          headers: {
            'content-type': 'text/plain',
            'content-length': '${bytes.length}',
          },
          request: request,
        );
      });
      app = admin.initializeApp(
        mocks.appOptions,
        'storage-read-${DateTime.now().microsecondsSinceEpoch}',
      );
      storage = app.storage();
    });

    tearDown(() async {
      AuthorizedHttpClient.httpClientFactory = previousFactory;
      await app.delete();
    });

    test('File.read downloads full object', () async {
      final chunks = await storage
          .bucket('upload-bucket')
          .file('docs/a.txt')
          .read()
          .toList();
      expect(utf8.decode(chunks.expand((c) => c).toList()), 'hello');
    });

    test('File.read supports offset and length', () async {
      final chunks = await storage
          .bucket('upload-bucket')
          .file('docs/a.txt')
          .read(offset: 1, length: 3)
          .toList();
      expect(utf8.decode(chunks.expand((c) => c).toList()), 'ell');
    });

    test('read requires length when offset is non-zero', () {
      expect(
        () => storage
            .bucket('upload-bucket')
            .file('a.txt')
            .read(offset: 1)
            .toList(),
        throwsArgumentError,
      );
    });
  });

  group('Storage info', () {
    late http.Client Function() previousFactory;
    late App app;
    late Storage storage;

    setUp(() {
      previousFactory = AuthorizedHttpClient.httpClientFactory;
      AuthorizedHttpClient.httpClientFactory = () => MockClient((
        request,
      ) async {
        expect(request.method, 'GET');
        expect(request.url.queryParameters['alt'], 'json');
        expect(request.url.queryParameters['projection'], 'full');
        return http.Response(
          jsonEncode({
            'kind': 'storage#object',
            'bucket': 'upload-bucket',
            'name': 'docs/a.txt',
            'contentType': 'text/plain',
            'cacheControl': 'public, max-age=3600',
            'size': '5',
            'generation': '42',
            'metageneration': '7',
            'etag': 'abc',
            'updated': '2024-01-02T03:04:05.000Z',
            'mediaLink':
                'https://storage.googleapis.com/download/storage/v1/b/upload-bucket/o/docs%2Fa.txt?alt=media',
            'md5Hash': 'XUFAKrxLKna5cZ2REBfFkg==',
            'crc32c': 'AAAAAA==',
            'metadata': {'env': 'test'},
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      app = admin.initializeApp(
        mocks.appOptions,
        'storage-info-${DateTime.now().microsecondsSinceEpoch}',
      );
      storage = app.storage();
    });

    tearDown(() async {
      AuthorizedHttpClient.httpClientFactory = previousFactory;
      await app.delete();
    });

    test('File.info returns ObjectInfo', () async {
      final info =
          await storage.bucket('upload-bucket').file('docs/a.txt').info();
      expect(info.bucket, 'upload-bucket');
      expect(info.name, 'docs/a.txt');
      expect(info.contentType, 'text/plain');
      expect(info.cacheControl, 'public, max-age=3600');
      expect(info.length, 5);
      expect(info.generation, '42');
      expect(info.metageneration, '7');
      expect(info.etag, 'abc');
      expect(info.updated, DateTime.utc(2024, 1, 2, 3, 4, 5));
      expect(info.downloadLink, isNotNull);
      expect(info.md5Hash, 'XUFAKrxLKna5cZ2REBfFkg==');
      expect(info.customMetadata, {'env': 'test'});
    });


  });

  group('Storage updateMetadata', () {
    late http.Client Function() previousFactory;
    late App app;
    late Storage storage;
    http.BaseRequest? lastRequest;

    setUp(() {
      previousFactory = AuthorizedHttpClient.httpClientFactory;
      lastRequest = null;
      AuthorizedHttpClient.httpClientFactory = () => MockClient((
        request,
      ) async {
        lastRequest = request;
        expect(request.method, 'PATCH');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'kind': 'storage#object',
            'bucket': 'upload-bucket',
            'name': 'docs/a.txt',
            'contentType': body['contentType'] ?? 'text/plain',
            'cacheControl': body['cacheControl'],
            'size': '5',
            'generation': '43',
            'metadata': body['metadata'] ?? {'env': 'test'},
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      app = admin.initializeApp(
        mocks.appOptions,
        'storage-update-meta-${DateTime.now().microsecondsSinceEpoch}',
      );
      storage = app.storage();
    });

    tearDown(() async {
      AuthorizedHttpClient.httpClientFactory = previousFactory;
      await app.delete();
    });

    test('File.updateMetadata patches fields', () async {
      final info = await storage
          .bucket('upload-bucket')
          .file('docs/a.txt')
          .updateMetadata(
            contentType: 'text/html',
            cacheControl: 'no-cache',
            metadata: {'env': 'prod'},
          );
      expect(info.contentType, 'text/html');
      expect(info.cacheControl, 'no-cache');
      expect(info.customMetadata, {'env': 'prod'});
      expect(info.generation, '43');
      expect(lastRequest!.method, 'PATCH');
      expect(lastRequest!.url.path, contains('/docs%2Fa.txt'));
    });

  });

  group('Storage getSignedUrl', () {
    late App app;
    late Storage storage;

    setUp(() {
      app = admin.initializeApp(
        mocks.appOptions,
        'storage-signed-${DateTime.now().microsecondsSinceEpoch}',
      );
      storage = app.storage();
    });

    tearDown(() async {
      await app.delete();
    });

    test('creates a V4 virtual-hosted signed URL', () async {
      await withClock(Clock.fixed(DateTime.utc(2024, 1, 2, 3, 4, 5)), () async {
        final url = await storage.bucket('my-bucket').file('docs/a.txt').getSignedUrl(
          expires: const Duration(hours: 1),
        );
        expect(url.scheme, 'https');
        expect(url.host, 'my-bucket.storage.googleapis.com');
        expect(url.path, '/docs/a.txt');
        expect(url.queryParameters['X-Goog-Algorithm'], 'GOOG4-RSA-SHA256');
        expect(
          url.queryParameters['X-Goog-Credential'],
          startsWith('foo@project_id.iam.gserviceaccount.com/20240102/auto/storage/goog4_request'),
        );
        expect(url.queryParameters['X-Goog-Date'], '20240102T030405Z');
        expect(url.queryParameters['X-Goog-Expires'], '3600');
        expect(url.queryParameters['X-Goog-SignedHeaders'], 'host');
        expect(url.queryParameters['X-Goog-Signature'], isNotEmpty);
        expect(
          url.queryParameters['X-Goog-Signature'],
          matches(RegExp(r'^[0-9a-f]+$')),
        );
      });
    });

    test('includes content-type in signed headers when provided', () async {
      final url = await storage.bucket('my-bucket').file('a.txt').getSignedUrl(
        action: SignedUrlAction.write,
        expires: const Duration(minutes: 15),
        contentType: 'text/plain',
      );
      expect(url.queryParameters['X-Goog-SignedHeaders'], 'content-type;host');
    });

    test('rejects expires longer than 7 days', () async {
      expect(
        () => storage.bucket('my-bucket').file('a.txt').getSignedUrl(
          expires: const Duration(days: 8),
        ),
        throwsFirebaseError('storage/invalid-argument'),
      );
    });
  });
}
