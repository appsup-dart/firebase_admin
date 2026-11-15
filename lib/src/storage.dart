import 'dart:async';

import 'package:_discoveryapis_commons/_discoveryapis_commons.dart';
// Prefer googleapis JSON API for now: supports delimiter/prefix listing.
// googleapis marks this library deprecated in favor of package:google_cloud_storage.
// ignore: deprecated_member_use
import 'package:googleapis/storage/v1.dart' as storage_api;

import '../firebase_admin.dart';
import 'service.dart';
import 'storage/download_url.dart';
import 'storage/signed_url.dart';
import 'utils/api_request.dart';

export 'storage/signed_url.dart' show SignedUrlAction;

/// Storage service bound to the provided app.
///
/// Do not construct directly — use [App.storage].
class Storage implements FirebaseService {
  @override
  final App app;

  final storage_api.StorageApi _client;

  /// Do not call this constructor directly. Instead, use [App.storage].
  Storage(this.app)
      : _client = storage_api.StorageApi(
          AuthorizedHttpClient(app, const Duration(seconds: 25)),
        );

  @override
  Future<void> delete() async {}

  /// Returns a reference to a Cloud Storage bucket.
  ///
  /// If [name] is omitted, uses [AppOptions.storageBucket]. Does not perform
  /// an RPC — mirrors Node/Python Admin `bucket()`.
  Bucket bucket([String? name]) {
    name ??= app.options.storageBucket;
    if (name != null && name.isNotEmpty) {
      return Bucket._(this, name);
    }
    throw FirebaseStorageError.invalidArgument(
      'Bucket name not specified or invalid. Specify a valid bucket name via the '
      'storageBucket option when initializing the app, or specify the bucket name '
      'explicitly when calling the getBucket() method.',
    );
  }
}

/// Reference to a Cloud Storage bucket.
///
/// Use [file] / [prefix] / [root] / [list] for navigation. Object operations
/// (read, write, metadata, URLs, …) live on [File].
class Bucket {
  final Storage _storage;
  final String name;

  Bucket._(this._storage, this.name);

  storage_api.StorageApi get _client => _storage._client;

  /// Absolute `gs://` object name for [objectName] in this bucket.
  String absoluteObjectName(String objectName) => 'gs://$name/$objectName';

  /// Reference to object [path] in this bucket (no RPC).
  ///
  /// [delimiter] is stored on the [File] so hierarchy helpers like
  /// [BucketItem.parent] use a consistent tree.
  File file(String path, {String delimiter = '/'}) =>
      File._(this, path, delimiter);

  /// Reference to a virtual directory [path] in this bucket (no RPC).
  ///
  /// [delimiter] defines the hierarchy and is fixed on this [Prefix] and on
  /// every [File] / [Prefix] returned from [Prefix.list]. For directory-style
  /// paths, prefer a trailing delimiter (e.g. `docs/` with delimiter `/`).
  Prefix prefix(String path, {String delimiter = '/'}) =>
      Prefix._(this, path, delimiter);

  /// Root of the bucket hierarchy — same as `prefix('', delimiter: delimiter)`.
  Prefix root({String delimiter = '/'}) => prefix('', delimiter: delimiter);

  /// Lists under [prefix] using [delimiter].
  ///
  /// Same as `this.prefix(prefix ?? '', delimiter: delimiter).list()`. Prefer
  /// [prefix] / [root] and [Prefix.list] when walking a hierarchy so the
  /// delimiter stays fixed on returned items.
  Stream<BucketItem> list({String? prefix, String delimiter = '/'}) =>
      this.prefix(prefix ?? '', delimiter: delimiter).list();

  Stream<BucketItem> _list({
    required String? prefix,
    required String delimiter,
  }) async* {
    String? pageToken;
    // Empty delimiter → recursive object listing (no common-prefix folders).
    final effectiveDelimiter = delimiter.isEmpty ? null : delimiter;
    try {
      do {
        final page = await _client.objects.list(
          name,
          prefix: prefix,
          delimiter: effectiveDelimiter,
          pageToken: pageToken,
        );
        for (final p in page.prefixes ?? const <String>[]) {
          yield Prefix._(this, p, delimiter);
        }
        for (final object in page.items ?? const <storage_api.Object>[]) {
          final objectName = object.name;
          if (objectName == null || objectName.isEmpty) continue;
          yield File._(this, objectName, delimiter);
        }
        pageToken = page.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);
    } on DetailedApiRequestError catch (error) {
      throw _storageError(error);
    }
  }
}

/// An entry from a hierarchical [Prefix.list] — either a [File] or a [Prefix].
sealed class BucketItem {
  /// Bucket this entry belongs to.
  final Bucket bucket;

  /// Object name, or common-prefix string (usually ends with the delimiter).
  final String name;

  /// Delimiter that defines the virtual directory tree for this item.
  final String delimiter;

  BucketItem._(this.bucket, this.name, this.delimiter);

  /// True for [Prefix], false for [File].
  bool get isDirectory;

  /// True for [File], false for [Prefix].
  bool get isObject => !isDirectory;

  /// Parent [Prefix] in this item's delimiter hierarchy, or `null` at the root
  /// / when [delimiter] is empty (flat listing — no hierarchy).
  Prefix? get parent {
    if (name.isEmpty || delimiter.isEmpty) return null;

    var path = name;
    if (isDirectory && path.endsWith(delimiter)) {
      path = path.substring(0, path.length - delimiter.length);
      if (path.isEmpty) return null;
    }

    final index = path.lastIndexOf(delimiter);
    if (index < 0) {
      return bucket.prefix('', delimiter: delimiter);
    }
    return bucket.prefix(
      path.substring(0, index + delimiter.length),
      delimiter: delimiter,
    );
  }
}

/// Reference to a Cloud Storage object.
class File extends BucketItem {
  File._(super.bucket, super.name, super.delimiter) : super._();

  @override
  bool get isDirectory => false;

  /// Whether this object exists.
  Future<bool> exists() async {
    try {
      await bucket._client.objects.get(bucket.name, name);
      return true;
    } on DetailedApiRequestError catch (error) {
      if (error.status == 404) return false;
      throw _storageError(error);
    }
  }

  /// Deletes this object.
  Future<void> delete() async {
    try {
      await bucket._client.objects.delete(bucket.name, name);
    } on DetailedApiRequestError catch (error) {
      throw _storageError(error);
    }
  }

  /// Copies this object to [destination].
  ///
  /// Runs entirely on Cloud Storage via the rewrite API (any object size).
  /// [destination] may be in another bucket. Optional named metadata fields
  /// override values on the destination; omitted fields are copied from the
  /// source. Returns the destination [ObjectInfo].
  Future<ObjectInfo> copy(
    File destination, {
    String? contentType,
    String? contentEncoding,
    String? cacheControl,
    String? contentDisposition,
    String? contentLanguage,
    Map<String, String>? metadata,
  }) async {
    try {
      final request = storage_api.Object()
        ..contentType = contentType
        ..contentEncoding = contentEncoding
        ..cacheControl = cacheControl
        ..contentDisposition = contentDisposition
        ..contentLanguage = contentLanguage
        ..metadata = metadata;

      String? rewriteToken;
      storage_api.RewriteResponse response;
      do {
        response = await bucket._client.objects.rewrite(
          request,
          bucket.name,
          name,
          destination.bucket.name,
          destination.name,
          rewriteToken: rewriteToken,
          projection: 'full',
        );
        rewriteToken = response.rewriteToken;
      } while (response.done != true);

      final resource = response.resource;
      if (resource == null) {
        throw FirebaseStorageError(
          'unknown-error',
          'Storage rewrite completed without returning object metadata.',
        );
      }
      return ObjectInfo._fromApi(resource);
    } on DetailedApiRequestError catch (error) {
      throw _storageError(error);
    }
  }

  /// Creates a V4 signed URL for this object.
  ///
  /// [expires] is measured from now and must be at most 7 days. Requires the
  /// app to be initialized with a service account credential that includes a
  /// private key. Optional [contentType] / [headers] must also be sent by the
  /// client when using the URL.
  Future<Uri> getSignedUrl({
    SignedUrlAction action = SignedUrlAction.read,
    required Duration expires,
    String? contentType,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    return createSignedUrl(
      app: bucket._storage.app,
      bucketName: bucket.name,
      objectName: name,
      action: action,
      expires: expires,
      contentType: contentType,
      headers: headers,
      queryParams: queryParams,
    );
  }

  /// Returns the Firebase download URL for this object.
  ///
  /// Uses the Firebase Storage HTTP API to read `downloadTokens` and builds
  /// `https://firebasestorage.googleapis.com/v0/b/…/o/…?alt=media&token=…`.
  /// Throws [FirebaseStorageError.noDownloadToken] when no token exists.
  /// Does not create a token — use [createDownloadURL] for that.
  Future<Uri> getDownloadURL() async {
    final metadata = await getFirebaseStorageMetadata(
      app: bucket._storage.app,
      bucketName: bucket.name,
      objectName: name,
    );
    return downloadUrlFromFirebaseMetadata(
      bucketName: bucket.name,
      objectName: name,
      metadata: metadata,
    );
  }

  /// Lists all Firebase download URLs for this object (may be empty).
  Future<List<Uri>> listDownloadURLs() async {
    final metadata = await getFirebaseStorageMetadata(
      app: bucket._storage.app,
      bucketName: bucket.name,
      objectName: name,
    );
    return downloadUrlsFromFirebaseMetadata(
      bucketName: bucket.name,
      objectName: name,
      metadata: metadata,
    );
  }

  /// Creates a new Firebase download token and returns its download URL.
  ///
  /// Always mints a new token (does not reuse existing ones). Equivalent to
  /// “Create new download URL” in the Firebase Console.
  Future<Uri> createDownloadURL() async {
    final info = await this.info();
    final tokens = parseDownloadTokens(
      info.customMetadata?[firebaseStorageDownloadTokensKey],
    );
    final token = generateDownloadToken();
    tokens.add(token);
    await _setDownloadTokens(tokens, existing: info.customMetadata);
    return firebaseDownloadUrl(
      bucketName: bucket.name,
      objectName: name,
      token: token,
    );
  }

  /// Revokes Firebase download URL access for this object.
  ///
  /// If [url] is omitted, all download tokens are removed. If [url] is given,
  /// only that URL's token is revoked. Throws if [url] does not refer to this
  /// object, or if its token is not present.
  Future<void> revokeDownloadURL([Uri? url]) async {
    final info = await this.info();
    final tokens = parseDownloadTokens(
      info.customMetadata?[firebaseStorageDownloadTokensKey],
    );
    if (url == null) {
      if (tokens.isEmpty) return;
      await _setDownloadTokens(const [], existing: info.customMetadata);
      return;
    }
    final token = downloadTokenFromUrl(
      url: url,
      bucketName: bucket.name,
      objectName: name,
    );
    if (!tokens.contains(token)) {
      throw FirebaseStorageError.invalidArgument(
        'Download URL token is not registered on this object.',
      );
    }
    tokens.remove(token);
    await _setDownloadTokens(tokens, existing: info.customMetadata);
  }

  Future<void> _setDownloadTokens(
    List<String> tokens, {
    Map<String, String>? existing,
  }) async {
    final custom = Map<String, String>.from(existing ?? const {});
    if (tokens.isEmpty) {
      custom.remove(firebaseStorageDownloadTokensKey);
    } else {
      custom[firebaseStorageDownloadTokensKey] = tokens.join(',');
    }
    await updateMetadata(metadata: custom);
  }

  /// Looks up metadata for this object.
  Future<ObjectInfo> info() async {
    try {
      final response = await bucket._client.objects.get(
        bucket.name,
        name,
        projection: 'full',
      );
      return ObjectInfo._fromApi(response as storage_api.Object);
    } on DetailedApiRequestError catch (error) {
      throw _storageError(error);
    }
  }

  /// Updates mutable metadata for this object.
  ///
  /// Only non-null arguments are patched. Returns the updated [ObjectInfo].
  Future<ObjectInfo> updateMetadata({
    String? contentType,
    String? contentEncoding,
    String? cacheControl,
    String? contentDisposition,
    String? contentLanguage,
    Map<String, String>? metadata,
  }) async {
    try {
      final request = storage_api.Object()
        ..contentType = contentType
        ..contentEncoding = contentEncoding
        ..cacheControl = cacheControl
        ..contentDisposition = contentDisposition
        ..contentLanguage = contentLanguage
        ..metadata = metadata;
      final response = await bucket._client.objects.patch(
        request,
        bucket.name,
        name,
        projection: 'full',
      );
      return ObjectInfo._fromApi(response);
    } on DetailedApiRequestError catch (error) {
      throw _storageError(error);
    }
  }

  /// Reads this object's content as a byte stream.
  ///
  /// If [offset] is non-zero, [length] must be provided. If [length] is
  /// provided, it must be greater than `0`.
  Stream<List<int>> read({int? offset, int? length}) async* {
    offset ??= 0;

    if (offset != 0 && length == null) {
      throw ArgumentError('length must have a value if offset is non-zero.');
    }

    var options = DownloadOptions.fullMedia;
    if (length != null) {
      if (length <= 0) {
        throw ArgumentError.value(
          length,
          'length',
          'If provided, length must greater than zero.',
        );
      }
      // ByteRange end is inclusive.
      options = PartialDownloadOptions(ByteRange(offset, offset + length - 1));
    }

    try {
      final response = await bucket._client.objects.get(
        bucket.name,
        name,
        downloadOptions: options,
      );
      final media = response as Media;
      yield* media.stream;
    } on DetailedApiRequestError catch (error) {
      throw _storageError(error);
    }
  }

  /// Writes [bytes] as this object's content, replacing any existing object.
  ///
  /// [contentType] defaults to `application/octet-stream`. Optional [metadata]
  /// is stored as custom object metadata (GCS `metadata` map).
  Future<ObjectInfo> writeBytes(
    List<int> bytes, {
    String contentType = 'application/octet-stream',
    Map<String, String>? metadata,
  }) {
    return _upload(
      Stream<List<int>>.value(bytes),
      length: bytes.length,
      contentType: contentType,
      metadata: metadata,
    );
  }

  /// Opens a sink to write this object's content, replacing any existing object.
  ///
  /// When [length] is known, a simple/multipart upload is used; otherwise a
  /// resumable upload. Closing the sink completes with [ObjectInfo].
  ObjectWriteSink write({
    int? length,
    String contentType = 'application/octet-stream',
    Map<String, String>? metadata,
  }) {
    return _ObjectWriteSink(
      length: length,
      contentType: contentType,
      metadata: metadata,
      upload: _upload,
    );
  }

  Future<ObjectInfo> _upload(
    Stream<List<int>> stream, {
    required int? length,
    required String contentType,
    required Map<String, String>? metadata,
  }) async {
    try {
      final request = storage_api.Object()
        ..name = name
        ..contentType = contentType
        ..metadata = metadata;
      final media = Media(stream, length, contentType: contentType);
      final uploaded = await bucket._client.objects.insert(
        request,
        bucket.name,
        name: name,
        uploadMedia: media,
        uploadOptions: length == null
            ? UploadOptions.resumable
            : UploadOptions.defaultOptions,
      );
      return ObjectInfo._fromApi(uploaded);
    } on DetailedApiRequestError catch (error) {
      throw _storageError(error);
    }
  }
}

/// Metadata for a Cloud Storage object.
class ObjectInfo {
  /// Bucket that contains the object.
  final String bucket;

  /// Object name (path within the bucket).
  final String name;

  /// MIME type, if set.
  final String? contentType;

  /// `Content-Encoding`, if set.
  final String? contentEncoding;

  /// `Cache-Control`, if set.
  final String? cacheControl;

  /// `Content-Disposition`, if set.
  final String? contentDisposition;

  /// `Content-Language`, if set.
  final String? contentLanguage;

  /// Object size in bytes, if known.
  final int? length;

  /// Object generation, if known.
  final String? generation;

  /// Metadata generation, if known.
  final String? metageneration;

  /// Entity tag, if known.
  final String? etag;

  /// Last update time, if known.
  final DateTime? updated;

  /// Direct media download link, if known.
  final Uri? downloadLink;

  /// Base64 MD5 hash, if known.
  final String? md5Hash;

  /// Base64 CRC32C checksum, if known.
  final String? crc32c;

  /// Custom metadata key/value pairs, if any.
  final Map<String, String>? customMetadata;

  ObjectInfo({
    required this.bucket,
    required this.name,
    this.contentType,
    this.contentEncoding,
    this.cacheControl,
    this.contentDisposition,
    this.contentLanguage,
    this.length,
    this.generation,
    this.metageneration,
    this.etag,
    this.updated,
    this.downloadLink,
    this.md5Hash,
    this.crc32c,
    this.customMetadata,
  });

  factory ObjectInfo._fromApi(storage_api.Object object) {
    return ObjectInfo(
      bucket: object.bucket ?? '',
      name: object.name ?? '',
      contentType: object.contentType,
      contentEncoding: object.contentEncoding,
      cacheControl: object.cacheControl,
      contentDisposition: object.contentDisposition,
      contentLanguage: object.contentLanguage,
      length: object.size == null ? null : int.tryParse(object.size!),
      generation: object.generation,
      metageneration: object.metageneration,
      etag: object.etag,
      updated: object.updated,
      downloadLink:
          object.mediaLink == null ? null : Uri.parse(object.mediaLink!),
      md5Hash: object.md5Hash,
      crc32c: object.crc32c,
      customMetadata: object.metadata == null
          ? null
          : Map<String, String>.from(object.metadata!),
    );
  }
}

/// [StreamSink] for [File.write]; [done]/[close] yield [ObjectInfo].
abstract class ObjectWriteSink implements StreamSink<List<int>> {
  @override
  Future<ObjectInfo> get done;

  @override
  Future<ObjectInfo> close();
}

class _ObjectWriteSink implements ObjectWriteSink {
  final int? length;
  final String contentType;
  final Map<String, String>? metadata;
  final Future<ObjectInfo> Function(
    Stream<List<int>> stream, {
    required int? length,
    required String contentType,
    required Map<String, String>? metadata,
  })
  upload;

  final _controller = StreamController<List<int>>();
  final _done = Completer<ObjectInfo>();
  var _started = false;

  _ObjectWriteSink({
    required this.length,
    required this.contentType,
    required this.metadata,
    required this.upload,
  });

  void _ensureStarted() {
    if (_started) return;
    _started = true;
    upload(
      _controller.stream,
      length: length,
      contentType: contentType,
      metadata: metadata,
    ).then(_done.complete, onError: _done.completeError);
  }

  @override
  void add(List<int> data) {
    _ensureStarted();
    _controller.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _ensureStarted();
    _controller.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    _ensureStarted();
    return _controller.addStream(stream);
  }

  @override
  Future<ObjectInfo> close() {
    _ensureStarted();
    return _controller.close().then((_) => _done.future);
  }

  @override
  Future<ObjectInfo> get done => _done.future;
}

/// A virtual directory in a delimiter-based listing hierarchy.
///
/// [delimiter] is fixed when the prefix is created ([Bucket.prefix],
/// [Bucket.root], or as a child of [Prefix.list]) and cannot be changed when
/// listing again.
class Prefix extends BucketItem {
  Prefix._(super.bucket, super.name, super.delimiter) : super._();

  @override
  bool get isDirectory => true;

  /// Lists immediate children under this prefix using [delimiter].
  ///
  /// Create a [Prefix] with an empty [delimiter] (via [Bucket.prefix] /
  /// [Bucket.root] / [Bucket.list]) for a recursive flat listing of objects
  /// only.
  Stream<BucketItem> list() => bucket._list(
        prefix: name.isEmpty ? null : name,
        delimiter: delimiter,
      );
}

FirebaseStorageError _storageError(DetailedApiRequestError error) {
  final response = error.jsonResponse;
  final apiError = response?['error'];
  if (apiError is Map) {
    final message = apiError['message'] as String? ?? error.message;
    return FirebaseStorageError(
      'unknown-error',
      message ?? 'Unexpected Storage API error (status: ${error.status}).',
    );
  }
  return FirebaseStorageError(
    'unknown-error',
    error.message ?? 'Unexpected Storage API error (status: ${error.status}).',
  );
}
