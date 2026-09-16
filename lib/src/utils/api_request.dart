import 'package:http/http.dart';

import '../app.dart';
import 'http_client.dart' as http_client;

class AuthorizedHttpClient extends BaseClient {
  final App app;

  final Duration? timeout;

  final Client client;

  AuthorizedHttpClient(this.app, [this.timeout])
      : client = http_client.resolveHttpClient();

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    var accessTokenObj = await app.internals.getToken();

    request.headers['Authorization'] = 'Bearer ${accessTokenObj.accessToken}';

    var r = client.send(request);
    if (timeout != null) r = r.timeout(timeout!);
    return r;
  }

  static Client Function() get httpClientFactory =>
      http_client.httpClientFactory;
  static set httpClientFactory(Client Function() factory) =>
      http_client.httpClientFactory = factory;
}
