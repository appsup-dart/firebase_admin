import 'dart:async';

import '../firebase_admin.dart';
import 'app/app.dart';
import 'database.dart';
import 'utils/error.dart';
import 'service.dart';
import 'auth.dart';
import 'credential.dart';
import 'package:meta/meta.dart';

/// Represents initialized Firebase application and provides access to the
/// app's services.
class App {
  final String _name;

  final AppOptions _options;

  final Map<Type, FirebaseService> _services = {};

  @visibleForTesting
  final FirebaseAppInternals internals;

  /// Do not call this constructor directly. Instead, use
  /// [FirebaseAdmin.initializeApp] to create an app.
  App(String name, AppOptions options)
      : _name = name,
        internals = FirebaseAppInternals(options.credential),
        _options = options;

  /// The name of this application.
  ///
  /// `[DEFAULT]` is the name of the default App.
  String get name {
    _checkDestroyed();
    return _name;
  }

  /// The (read-only) configuration options for this app.
  ///
  /// These are the original parameters given in [FirebaseAdmin.initializeApp].
  AppOptions get options {
    _checkDestroyed();
    return _options;
  }

  /// Gets the [Auth] service for this application.
  Auth auth() => _getService(() => Auth(this));

  /// Gets Realtime [Database] client for this application.
  Database database() => _getService(() => Database(this));

  /// Renders this app unusable and frees the resources of all associated
  /// services.
  Future<void> delete() async {
    _checkDestroyed();
    FirebaseAdmin.instance.removeApp(_name);

    internals.delete();

    await Future.wait(_services.values.map((v) => v.delete()));
    _services.clear();
  }

  T _getService<T extends FirebaseService>(T Function() factory) {
    _checkDestroyed();
    return _services[T] ??= factory();
  }

  /// Throws an Error if the FirebaseApp instance has already been deleted.
  void _checkDestroyed() {
    if (internals.isDeleted) {
      throw FirebaseAppError.appDeleted(
        'Firebase app named "${_name}" has already been deleted.',
      );
    }
  }
}

/// Available options to pass to initializeApp().
class AppOptions {
  /// A [Credential] object used to authenticate the Admin SDK.
  ///
  /// You can obtain a credential via one of the following methods:
  ///
  /// - [applicationDefaultCredential]
  /// - [cert]
  /// - [refreshToken]
  final Credential credential;

  /// The URL of the Realtime Database from which to read and write data.
  final String databaseUrl;

  /// The ID of the Google Cloud project associated with the App.
  final String projectId;

  /// The name of the default Cloud Storage bucket associated with the App.
  final String storageBucket;

  AppOptions({
    this.credential,
    this.databaseUrl,
    this.projectId,
    this.storageBucket,
  });
}
