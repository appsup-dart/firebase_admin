// @dart=2.9

import 'package:firebase_admin/src/service.dart';

import '../firebase_admin.dart';
import 'app/app_extension.dart';
import 'app.dart';

import 'package:firebase_dart/standalone_database.dart';

/// Firebase Realtime Database service.
class Database implements FirebaseService {
  final StandaloneFirebaseDatabase _database;

  @override
  final App app;

  /// Do not call this constructor directly. Instead, use app().database.
  Database(this.app)
      : _database = StandaloneFirebaseDatabase(app.options.databaseUrl ??
            'https://${app.projectId}.firebaseio.com/') {
    _database.authenticate(app.internals.getToken().then((v) => v.accessToken));

    app.internals
        .addAuthTokenListener((token) => _database.authenticate(token));
  }

  /// Returns a [Reference] representing the location in the Database
  /// corresponding to the provided [path]. If no path is provided, the
  /// Reference will point to the root of the Database.
  DatabaseReference ref([String path]) =>
      _database.reference().child(path ?? '');

  @override
  Future<void> delete() async {
    await _database.app.delete();
  }
}
