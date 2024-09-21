import 'package:firebase_admin/src/app.dart';
import 'package:firebase_admin/src/app/app_extension.dart';
import 'package:firebase_admin/src/firestore/collection.dart';
import 'package:firebase_admin/src/firestore/document.dart';
import 'package:firebase_admin/src/firestore/transaction.dart';
import 'package:firebase_admin/src/firestore/utils/serialization.dart';
import 'package:firebase_admin/src/service.dart';
import 'package:firebase_admin/src/utils/api_request.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:meta/meta.dart';

typedef ToFirestore<T> = Map<String, dynamic> Function(T value);
typedef FromFirestore<T> = T Function(DocumentSnapshot<Map<String, dynamic>> snapshot);

class Firestore implements FirebaseService {
  @override
  final App app;

  final FirestoreApi _api;

  @internal
  ProjectsDatabasesDocumentsResource get docsApi => _api.projects.databases.documents;

  @internal
  String get databasePath => 'projects/${app.projectId}/databases/(default)/documents';

  Firestore(this.app) : _api = FirestoreApi(AuthorizedHttpClient(app));

  @override
  Future<void> delete() async {}

  CollectionReference<Map<String, dynamic>> collection(String id) {
    return CollectionReference(
      firestore: this,
      fromFirestore: fromFirestore,
      toFirestore: toFirestore,
      path: id,
    );
  }

  DocumentReference<Map<String, dynamic>> doc(String id) {
    return DocumentReference(
      firestore: this,
      fromFirestore: fromFirestore,
      toFirestore: toFirestore,
      path: id,
    );
  }

  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) handler, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    return Transaction.run(
      firestore: this,
      timeout: timeout,
      handler: handler,
    );
  }
}
