import 'package:firebase_admin/src/firestore/document.dart';
import 'package:firebase_admin/src/firestore/firestore.dart';
import 'package:firebase_admin/src/firestore/query.dart';
import 'package:firebase_admin/src/firestore/utils/document_snapshot.dart';
import 'package:firebase_admin/src/firestore/utils/serialization.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:meta/meta.dart';

class Transaction {
  final Firestore firestore;
  final String id;

  final List<Write> _writes;

  Transaction._({
    required this.firestore,
    required this.id,
  }) : _writes = <Write>[];

  Future<DocumentSnapshot<T>> get<T>(DocumentReference<T> ref) async {
    final result = await firestore.docsApi.get(
      '${firestore.databasePath}/${ref.path}',
      transaction: id,
    );

    return SerializableDocumentSnapshot(
      firestore: firestore,
      toFirestore: ref.toFirestore,
      fromFirestore: ref.fromFirestore,
      document: result,
    );
  }

  Future<QuerySnapshot<T>> getBy<T>(Query<T> query) async {
    return query.get(transactionId: id);
  }

  void set<T>(DocumentReference<T> ref, T data) {
    _writes.add(Write(
      currentDocument: Precondition(exists: false),
      update: Document(
        name: '${firestore.databasePath}/${ref.path}',
        fields: serializeData(ref.toFirestore(data)),
      ),
    ));
  }

  void update(DocumentReference<Object?> ref, Map<String, dynamic> data) {
    _writes.add(Write(
      currentDocument: Precondition(exists: true),
      update: Document(
        name: '${firestore.databasePath}/${ref.path}',
        fields: serializeData(data),
      ),
    ));
  }

  void delete(DocumentReference<Object?> ref) {
    _writes.add(Write(
      delete: '${firestore.databasePath}/${ref.path}',
    ));
  }

  @internal
  static Future<T> run<T>({
    required Firestore firestore,
    Duration timeout = const Duration(seconds: 30),
    // int maxAttempts = 5, TODO: Implement it
    required Future<T> Function(Transaction transaction) handler,
  }) async {
    assert(timeout.inMilliseconds > 0, 'Transaction timeout must be more than 0 milliseconds');

    final beginTransactionRequest = BeginTransactionRequest();
    final transactionResponse = await firestore.docsApi.beginTransaction(
      beginTransactionRequest,
      firestore.databasePath,
    );
    try {
      final transaction = Transaction._(
        firestore: firestore,
        id: transactionResponse.transaction!,
      );
      final result = await handler(transaction).timeout(timeout);

      final commitRequest = CommitRequest(
        transaction: transactionResponse.transaction,
        writes: transaction._writes,
      );

      await firestore.docsApi.commit(commitRequest, firestore.databasePath);
      return result;
    } catch (_) {
      final rollbackRequest = RollbackRequest(
        transaction: transactionResponse.transaction,
      );
      await firestore.docsApi.rollback(rollbackRequest, firestore.databasePath);
      rethrow;
    }
  }
}
