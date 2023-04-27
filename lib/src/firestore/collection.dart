import 'package:firebase_admin/src/firestore/document.dart';
import 'package:firebase_admin/src/firestore/firestore.dart';
import 'package:firebase_admin/src/firestore/query.dart';
import 'package:firebase_admin/src/firestore/utils/auto_id_generator.dart';
import 'package:firebase_admin/src/firestore/utils/pointer.dart';

class CollectionReference<T> extends Query<T> {
  final Pointer _pointer;

  CollectionReference({
    required super.firestore,
    required super.toFirestore,
    required super.fromFirestore,
    required super.path,
  })  : _pointer = Pointer(path),
        super(query: null) {
    assert(_pointer.isCollection());
  }

  DocumentReference<T> doc([String? id]) {
    return DocumentReference(
      firestore: firestore,
      toFirestore: toFirestore,
      fromFirestore: fromFirestore,
      path: _pointer.documentPath(id ?? AutoIdGenerator.autoId()),
    );
  }

  Future<DocumentSnapshot<T>> add(T data) async {
    final document = doc();
    return await document.set(data);
  }

  CollectionReference<R> withConverter<R>({
    required FromFirestore<R> fromFirestore,
    required ToFirestore<R> toFirestore,
  }) {
    return CollectionReference<R>(
      firestore: firestore,
      path: path,
      fromFirestore: fromFirestore,
      toFirestore: toFirestore,
    );
  }
}
