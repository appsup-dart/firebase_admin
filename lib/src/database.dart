import 'package:firebase_admin/src/service.dart';

import '../firebase_admin.dart';
import 'app/app_extension.dart';
import 'app.dart';

import 'package:firebase_dart/firebase_dart.dart';

/// Firebase Realtime Database service.
class Database implements FirebaseService {
  final Firebase _rootRef;

  @override
  final App app;

  /// Do not call this constructor directly. Instead, use app().database.
  Database(this.app)
      : _rootRef = Firebase(app.options.databaseUrl ??
            'https://${app.projectId}.firebaseio.com/') {
    _rootRef.authenticate(app.internals.getToken().then((v) => v.accessToken));
    app.internals.addAuthTokenListener((token) => _rootRef.authenticate(token));
  }

  /// Returns a [Reference] representing the location in the Database
  /// corresponding to the provided [path]. If no path is provided, the
  /// Reference will point to the root of the Database.
  Firebase ref([String path]) => _rootRef.child(path ?? '');

  @override
  Future<void> delete() async {
    // TODO: implement delete
  }
}
