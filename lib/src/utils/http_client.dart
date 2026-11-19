import 'package:http/http.dart';
// ignore: implementation_imports
import 'package:firebase_dart/src/implementation/dart.dart';

Client _defaultHttpClientFactory() => Client();

/// Creates the client for Admin API calls.
///
/// A factory that is set here is always used, so a mock installed by a test
/// stays in place after [FirebaseDart.setup]. The default only applies when
/// [FirebaseDart.setup] has not been called.
Client Function() httpClientFactory = _defaultHttpClientFactory;

/// The client from [httpClientFactory] if one was set. Otherwise the
/// [http.Client] from [FirebaseDart.setup] if an implementation is installed,
/// or a new [Client].
///
/// Callers must not close the returned client; it may be shared.
Client resolveHttpClient() {
  if (!identical(httpClientFactory, _defaultHttpClientFactory)) {
    return httpClientFactory();
  }
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
