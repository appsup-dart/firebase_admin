import 'package:firebase_admin/src/firestore/firestore.dart';
import 'package:firebase_admin/src/firestore/utils/document_snapshot.dart';
import 'package:firebase_admin/src/firestore/utils/pointer.dart';
import 'package:firebase_admin/src/firestore/utils/serialization.dart';
import 'package:googleapis/firestore/v1.dart';

class DocumentReference<T> {
  final Firestore firestore;
  final ToFirestore<T> toFirestore;
  final FromFirestore<T> fromFirestore;
  final Pointer _pointer;
  String get path => _pointer.path;
  String get id => _pointer.id;

  DocumentReference({
    required this.firestore,
    required this.toFirestore,
    required this.fromFirestore,
    required String path,
  }) : _pointer = Pointer(path) {
    assert(_pointer.isDocument());
  }

  Future<DocumentSnapshot<T>> set(T data) async {
    final result = await firestore.docsApi.createDocument(
      Document(fields: serializeData(toFirestore(data))),
      firestore.databasePath,
      _pointer.parentPath()!,
      documentId: _pointer.id,
    );

    return SerializableDocumentSnapshot(
      firestore: firestore,
      toFirestore: toFirestore,
      fromFirestore: fromFirestore,
      document: result,
    );
  }

  Future<DocumentSnapshot<T>> get() async {
    final result = await firestore.docsApi.get('${firestore.databasePath}/$path');

    return SerializableDocumentSnapshot(
      firestore: firestore,
      toFirestore: toFirestore,
      fromFirestore: fromFirestore,
      document: result,
    );
  }

  Future<DocumentSnapshot<T>> update(Map<String, dynamic> data) async {
    final result = await firestore.docsApi.patch(
      Document(fields: serializeData(data)),
      '${firestore.databasePath}/${_pointer.path}',
    );

    return SerializableDocumentSnapshot(
      firestore: firestore,
      toFirestore: toFirestore,
      fromFirestore: fromFirestore,
      document: result,
    );
  }

  Future<void> delete() async {
    await firestore.docsApi.delete('${firestore.databasePath}/$path');
  }

  DocumentReference<R> withConverter<R>({
    required FromFirestore<R> fromFirestore,
    required ToFirestore<R> toFirestore,
  }) {
    return DocumentReference<R>(
      firestore: firestore,
      path: path,
      fromFirestore: fromFirestore,
      toFirestore: toFirestore,
    );
  }
}

abstract class DocumentSnapshot<T> {
  final Firestore firestore;

  const DocumentSnapshot({
    required this.firestore,
  });

  DocumentReference<T> get reference;

  T data();
}
