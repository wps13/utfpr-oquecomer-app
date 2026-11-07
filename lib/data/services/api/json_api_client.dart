import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// O chamador gerencia o ciclo de vida do cliente HTTP injetado.
class JsonApiClient {
  const JsonApiClient({required this.client});

  final http.Client client;

  Future<http.Response> postJson(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, Object?> body,
    required Duration timeout,
  }) async {
    final abort = Completer<void>();
    final request =
        http.AbortableRequest('POST', uri, abortTrigger: abort.future)
          ..headers.addAll({'Content-Type': 'application/json', ...headers})
          ..body = jsonEncode(body);

    Future<http.Response> send() async {
      final response = await client.send(request);
      return http.Response.fromStream(response);
    }

    try {
      // Inclui o corpo no prazo e cancela o transporte ao vencer.
      return await send().timeout(timeout);
    } finally {
      abort.complete();
    }
  }
}
