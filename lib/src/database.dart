import 'dart:async';

import 'package:firebase_admin/src/service.dart';

import 'app/app.dart';
import 'app/app_extension.dart';
import 'app.dart';

import 'package:firebase_dart/standalone_database.dart';

class _AuthTokenProvider implements AuthTokenProvider {
  final FirebaseAppInternals internals;

  _AuthTokenProvider(this.internals);

  @override
  Future<String?> getToken([bool forceRefresh = false]) async {
    return (await internals.getToken(forceRefresh)).accessToken;
  }

  @override
  Stream<Future<String>?> get onTokenChanged {
    var controller = StreamController<Future<String>?>();
    var listener = (v) => controller.add(Future.value(v));

    controller.onListen = () {
      internals.addAuthTokenListener(listener);
    };
    controller.onCancel = () => internals.removeAuthTokenListener(listener);

    return controller.stream;
  }
}

/// Firebase Realtime Database service.
class Database implements FirebaseService {
  final StandaloneFirebaseDatabase _database;

  @override
  final App app;

  /// Do not call this constructor directly. Instead, use app().database.
  Database(this.app)
      : _database = StandaloneFirebaseDatabase(
            app.options.databaseUrl ??
                'https://${app.projectId}.firebaseio.com/',
            authTokenProvider: _AuthTokenProvider(app.internals));

  /// Returns a [Reference] representing the location in the Database
  /// corresponding to the provided [path]. If no path is provided, the
  /// Reference will point to the root of the Database.
  DatabaseReference ref([String? path]) =>
      _database.reference().child(path ?? '');

  @override
  Future<void> delete() async {
    await _database.app.delete();
  }
}
