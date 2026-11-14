import 'package:_discoveryapis_commons/_discoveryapis_commons.dart';
// Prefer googleapis JSON API for now: supports delimiter/prefix listing.
// googleapis marks this library deprecated in favor of package:google_cloud_storage.
// ignore: deprecated_member_use
import 'package:googleapis/storage/v1.dart' as storage_api;

import '../firebase_admin.dart';
import 'service.dart';
import 'utils/api_request.dart';

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

/// Reference to a Cloud Storage bucket owned by this package (not `gcloud`).
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
