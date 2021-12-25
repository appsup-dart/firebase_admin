import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_admin/src/utils/api_request.dart';
import 'package:gcloud/storage.dart' as gcloud;

import 'package:firebase_admin/src/service.dart';
import 'app/app_extension.dart';

/// Storage service bound to the provided app.
class Storage implements FirebaseService {
  @override
  final App app;

  final gcloud.Storage storageClient;

  Storage(this.app)
      : storageClient = gcloud.Storage(
            AuthorizedHttpClient(app, Duration(seconds: 25)), app.projectId);

  @override
  Future<void> delete() async {}

  /// Returns a reference to a Google Cloud Storage bucket.
  ///
  /// Returned reference can be used to upload and download content from Google
  /// Cloud Storage.
  gcloud.Bucket bucket([String? name]) {
    name ??= app.options.storageBucket;
    if (name != null && name.isNotEmpty) {
      return storageClient.bucket(name);
    }
    throw FirebaseStorageError.invalidArgument(
        'Bucket name not specified or invalid. Specify a valid bucket name via the '
        'storageBucket option when initializing the app, or specify the bucket name '
        'explicitly when calling the getBucket() method.');
  }
}
