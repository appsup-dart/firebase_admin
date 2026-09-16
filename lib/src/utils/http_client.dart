import 'package:http/http.dart';
// ignore: implementation_imports
import 'package:firebase_dart/src/implementation/dart.dart';

/// Fallback used when [FirebaseDart.setup] has not been called.
Client Function() httpClientFactory = () => Client();

/// The [http.Client] from [FirebaseDart.setup] if an implementation is
/// installed, otherwise [httpClientFactory].
///
/// Callers must not close the returned client; it may be shared.
Client resolveHttpClient() {
  try {
    // Prefer the setup client when firebase_dart exposes it. Older versions
    // without this getter throw, and we fall back to [httpClientFactory].
    // ignore: avoid_dynamic_calls
    var client =
        (PureDartFirebaseImplementation.installation as dynamic).httpClient;
    if (client is Client) return client;
  } catch (_) {}
  return httpClientFactory();
}
