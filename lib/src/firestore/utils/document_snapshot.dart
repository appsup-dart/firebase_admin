import 'package:firebase_admin/src/firestore/document.dart';
import 'package:firebase_admin/src/firestore/firestore.dart';
import 'package:firebase_admin/src/firestore/utils/serialization.dart';
import 'package:googleapis/firestore/v1.dart';

class SerializableDocumentSnapshot<T> extends DocumentSnapshot<T> {
  final Document _document;
  final ToFirestore<T> toFirestore;
  final FromFirestore<T> fromFirestore;

  const SerializableDocumentSnapshot({
    required super.firestore,
    required this.toFirestore,
    required this.fromFirestore,
    required Document document,
  }) : _document = document;

  @override
  DocumentReference<T> get reference => DocumentReference(
        firestore: firestore,
        path: _document.name!,
        toFirestore: toFirestore,
        fromFirestore: fromFirestore,
      );

  @override
  T data() => fromFirestore(_RawDocumentSnapshot(firestore: firestore, document: _document));
}

class _RawDocumentSnapshot extends DocumentSnapshot<Map<String, dynamic>> {
  final Document _document;

  const _RawDocumentSnapshot({
    required super.firestore,
    required Document document,
  }) : _document = document;

  @override
  DocumentReference<Map<String, dynamic>> get reference => DocumentReference(
        firestore: firestore,
        path: _document.name!,
        fromFirestore: fromFirestore,
        toFirestore: toFirestore,
      );

  @override
  Map<String, dynamic> data() => deserializeData(firestore, _document.fields!);
}
