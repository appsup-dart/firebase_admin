import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_admin/src/firestore/document.dart';
import 'package:googleapis/firestore/v1.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;

import '../firestore.dart';

Map<String, dynamic> fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) =>
    snapshot.data();

Map<String, dynamic> toFirestore(Map<String, dynamic> value) => value;

Map<String, dynamic> deserializeData(Firestore firestore, Map<String, Value> fields) {
  return fields.map((key, value) => MapEntry(key, deserializeValue(firestore, value)));
}

Map<String, Value> serializeData(Map<String, dynamic> data) {
  return data.map((key, value) => MapEntry(key, serializeValue(value)));
}

dynamic deserializeValue(Firestore firestore, Value value) {
  if (value.arrayValue != null) {
    return value.arrayValue!.values!.map((value) => deserializeValue(firestore, value)).toList();
  } else if (value.booleanValue != null) {
    return value.booleanValue!;
  } else if (value.bytesValue != null) {
    return base64.decode(value.bytesValue!);
  } else if (value.doubleValue != null) {
    return value.doubleValue!;
  } else if (value.geoPointValue != null) {
    return maps_toolkit.LatLng(value.geoPointValue!.latitude!, value.geoPointValue!.longitude!);
  } else if (value.integerValue != null) {
    return int.parse(value.integerValue!);
  } else if (value.mapValue != null) {
    return deserializeData(firestore, value.mapValue!.fields!);
  } else if (value.nullValue != null) {
    return null;
  } else if (value.referenceValue != null) {
    return DocumentReference<Map<String, dynamic>>(
      firestore: firestore,
      fromFirestore: fromFirestore,
      toFirestore: toFirestore,
      path: value.referenceValue!,
    );
  } else if (value.stringValue != null) {
    return value.stringValue!;
  } else if (value.timestampValue != null) {
    return DateTime.fromMicrosecondsSinceEpoch(int.parse(value.timestampValue!));
  }
}

Value serializeValue(dynamic data) {
  return Value(
    arrayValue: data is List ? ArrayValue(values: data.map(serializeValue).toList()) : null,
    booleanValue: data is bool ? data : null,
    bytesValue:
        data is Uint8List ? base64.encode(data).replaceAll('/', '_').replaceAll('+', '-') : null,
    doubleValue: data is double ? data : null,
    geoPointValue: data is maps_toolkit.LatLng
        ? LatLng(latitude: data.latitude, longitude: data.longitude)
        : null,
    integerValue: data is int ? '$data' : null,
    mapValue: data is Map<String, dynamic> ? MapValue(fields: serializeData(data)) : null,
    nullValue: data == null ? 'nullValue' : null,
    referenceValue: data is DocumentReference<Map<String, dynamic>> ? data.path : null,
    stringValue: data is String ? data : null,
    timestampValue: data is DateTime ? '${data.microsecondsSinceEpoch}' : null,
  );
}
