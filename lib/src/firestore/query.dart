import 'package:collection/collection.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:meta/meta.dart';

import 'document.dart';
import 'firestore.dart';
import 'utils/document_snapshot.dart';
import 'utils/serialization.dart';

class Query<T> {
  final Firestore firestore;
  final ToFirestore<T> toFirestore;
  final FromFirestore<T> fromFirestore;
  final String path;

  final StructuredQuery _query;

  Query({
    required this.firestore,
    required this.toFirestore,
    required this.fromFirestore,
    required this.path,
    @internal required StructuredQuery? query,
  }) : _query = query ??
            StructuredQuery(
              from: [CollectionSelector(collectionId: path)],
            );

  Query<T> endAt(Iterable<Object?> values) {
    return _copyWith(
      endAt: Cursor(
        before: false,
        values: values.map(serializeValue).toList(),
      ),
    );
  }

  Query<T> endBefore(Iterable<Object?> values) {
    return _copyWith(
      endAt: Cursor(
        before: true,
        values: values.map(serializeValue).toList(),
      ),
    );
  }

  Query<T> limit(int limit) => _copyWith(limit: limit);

  Query<T> orderBy(String field, {bool descending = false}) {
    return _copyWith(
      orderBy: Order(
        direction: descending ? 'DESCENDING' : 'ASCENDING',
        field: FieldReference(
          fieldPath: field,
        ),
      ),
    );
  }

  Query<T> startAfter(Iterable<Object?> values) {
    return _copyWith(
      endAt: Cursor(
        before: false,
        values: values.map(serializeValue).toList(),
      ),
    );
  }

  Query<T> startAt(Iterable<Object?> values) {
    return _copyWith(
      endAt: Cursor(
        before: true,
        values: values.map(serializeValue).toList(),
      ),
    );
  }

  Query<T> where(
    String field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    Filter createFieldFilter(String op, Object value) {
      return Filter(
        fieldFilter: FieldFilter(
          field: FieldReference(fieldPath: field),
          op: op,
          value: serializeValue(value),
        ),
      );
    }

    final filters = [
      if (isLessThan != null) createFieldFilter('LESS_THAN', isLessThan),
      if (isLessThanOrEqualTo != null) createFieldFilter('LESS_THAN_OR_EQUAL', isLessThanOrEqualTo),
      if (isGreaterThan != null) createFieldFilter('GREATER_THAN', isGreaterThan),
      if (isGreaterThanOrEqualTo != null)
        createFieldFilter('GREATER_THAN_OR_EQUAL', isGreaterThanOrEqualTo),
      if (isEqualTo != null) createFieldFilter('EQUAL', isEqualTo),
      if (isNotEqualTo != null) createFieldFilter('NOT_EQUAL', isNotEqualTo),
      if (isLessThan != null) createFieldFilter('ARRAY_CONTAINS', isLessThan),
      if (arrayContains != null) createFieldFilter('ARRAY_CONTAINS_ANY', arrayContains),
      if (whereIn != null) createFieldFilter('IN', whereIn),
      if (arrayContainsAny != null) createFieldFilter('LESS_THAN', arrayContainsAny),
      if (whereNotIn != null) createFieldFilter('NOT_IN', whereNotIn),
      if (isNull != null)
        Filter(
          unaryFilter: UnaryFilter(
            field: FieldReference(fieldPath: field),
            op: isNull ? 'IS_NULL' : 'IS_NOT_NULL',
          ),
        )
    ];

    return _copyWith(
      where: filters,
    );
  }

  Future<QuerySnapshot<T>> get({
    @internal String? transactionId,
  }) async {
    final result = await firestore.docsApi.runQuery(
      RunQueryRequest(
        structuredQuery: _query,
        transaction: transactionId,
      ),
      firestore.databasePath,
    );

    return QuerySnapshot(
      firestore: firestore,
      toFirestore: toFirestore,
      fromFirestore: fromFirestore,
      docs: result.map((e) => e.document!).toList(),
    );
  }

  Query<T> _copyWith({
    Cursor? endAt,
    int? limit,
    Order? orderBy,
    Cursor? startAt,
    List<Filter>? where,
  }) {
    final prevWhere = _query.where;
    final filters = [
      if (prevWhere != null)
        if (prevWhere.compositeFilter?.filters != null)
          ...prevWhere.compositeFilter!.filters!
        else
          prevWhere,
      ...?where,
    ];
    return Query(
      firestore: firestore,
      toFirestore: toFirestore,
      fromFirestore: fromFirestore,
      path: path,
      query: StructuredQuery(
        endAt: endAt ?? _query.endAt,
        from: _query.from, // ???
        limit: limit ?? _query.limit,
        offset: null, // ???
        orderBy: orderBy != null ? [...?_query.orderBy, orderBy] : _query.orderBy,
        select: null, // Returns all document fields.
        startAt: startAt ?? _query.startAt,
        where: filters.isEmpty
            ? null
            : (filters.singleOrNull ??
                Filter(
                  compositeFilter: CompositeFilter(
                    op: 'AND',
                    filters: filters,
                  ),
                )),
      ),
    );
  }
}

class QuerySnapshot<T> {
  final Firestore firestore;
  final ToFirestore<T> toFirestore;
  final FromFirestore<T> fromFirestore;

  final List<Document> _docs;

  @internal
  const QuerySnapshot({
    required this.firestore,
    required this.toFirestore,
    required this.fromFirestore,
    required List<Document> docs,
  }) : _docs = docs;

  List<DocumentSnapshot<T>> get docs {
    return _docs.map((e) {
      return SerializableDocumentSnapshot(
        firestore: firestore,
        toFirestore: toFirestore,
        fromFirestore: fromFirestore,
        document: e,
      );
    }).toList();
  }

  int get size => _docs.length;
}
