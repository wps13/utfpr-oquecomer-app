import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../config/gemini_config.dart';
import '../../../domain/models/ai_failure.dart';
import '../api/json_api_client.dart';
import 'gemini_prompts.dart';

/// Transporte REST do Gemini. Não armazena histórico e não persiste resultados.
class GeminiService {
  const GeminiService({required this.apiClient, required this.config});

  final JsonApiClient apiClient;
  final GeminiConfig config;

  Future<Map<String, Object?>> generateJson({
    required String prompt,
    required Map<String, Object?> schema,
    Uint8List? imageBytes,
    String? mimeType,
  }) async {
    if (!config.isValid) {
      _debugLog(
        'generateJson: configuração inválida '
        '(motivos=${config.invalidReasons.join('; ')}, '
        'apiKeyPresent=${config.apiKey.trim().isNotEmpty}, '
        'apiKeyLength=${config.apiKey.trim().length}, '
        'model=${config.model}, temperature=${config.temperature}, '
        'maxOutputTokens=${config.maxOutputTokens}, '
        'timeout=${config.timeout.inSeconds}s)',
      );
      throw const AiFailure(AiFailureKind.configuration);
    }
    final parts = <Map<String, Object?>>[
      {'text': prompt},
      if (imageBytes != null)
        {
          'inlineData': {
            'mimeType': mimeType,
            'data': base64Encode(imageBytes),
          },
        },
    ];
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/${config.model}:generateContent',
    );
    try {
      _debugLog(
        'generateJson: enviando requisição '
        '(model=${config.model}, imagem=${imageBytes != null}, '
        'bytes=${imageBytes?.length ?? 0}, '
        'timeout=${config.timeout.inSeconds}s)',
      );
      final response = await apiClient.postJson(
        uri,
        headers: {'x-goog-api-key': config.apiKey.trim()},
        body: {
          'systemInstruction': {
            'parts': [
              {'text': GeminiPrompts.system},
            ],
          },
          'contents': [
            {'role': 'user', 'parts': parts},
          ],
          'generationConfig': {
            'temperature': config.temperature,
            'maxOutputTokens': config.maxOutputTokens,
            'candidateCount': 1,
            'responseFormat': {
              'text': {'mimeType': 'APPLICATION_JSON', 'schema': schema},
            },
          },
        },
        timeout: config.timeout,
      );
      _debugLog('generateJson: resposta HTTP ${response.statusCode}');
      _checkStatus(response.statusCode);
      if (response.bodyBytes.isEmpty) {
        _debugLog('generateJson: resposta HTTP sem corpo');
        throw const AiFailure(AiFailureKind.emptyResponse);
      }
      return _parseEnvelope(jsonDecode(utf8.decode(response.bodyBytes)));
    } on AiFailure catch (failure) {
      _debugLog('generateJson: AiFailure kind=${failure.kind.name}');
      rethrow;
    } on TimeoutException {
      _debugLog('generateJson: timeout');
      throw const AiFailure(AiFailureKind.timeout);
    } on http.ClientException catch (error, stackTrace) {
      // IOClient encapsula falhas de socket/DNS em ClientException.
      _debugLog(
        'generateJson: erro de conexão ${error.runtimeType}',
        stackTrace,
      );
      throw const AiFailure(AiFailureKind.connection);
    } on FormatException catch (error, stackTrace) {
      _debugLog(
        'generateJson: resposta inválida ${error.runtimeType}',
        stackTrace,
      );
      throw const AiFailure(AiFailureKind.invalidResponse);
    } on Object catch (error, stackTrace) {
      _debugLog(
        'generateJson: erro inesperado ${error.runtimeType}',
        stackTrace,
      );
      rethrow;
    }
  }

  static void _checkStatus(int status) {
    if (status >= 200 && status < 300) return;
    _debugLog('_checkStatus: HTTP $status');
    final kind = switch (status) {
      400 || 401 || 403 || 404 => AiFailureKind.configuration,
      408 || 504 => AiFailureKind.timeout,
      429 => AiFailureKind.quotaExceeded,
      >= 500 => AiFailureKind.unavailable,
      _ => AiFailureKind.unexpected,
    };
    throw AiFailure(kind);
  }

  static void _debugLog(String message, [StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    debugPrint('[GeminiService] $message');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }

  static Map<String, Object?> _parseEnvelope(Object? decoded) {
    if (decoded is! Map<String, Object?>) {
      throw const AiFailure(AiFailureKind.invalidResponse);
    }
    final feedback = decoded['promptFeedback'];
    if (feedback is Map && feedback['blockReason'] is String) {
      throw const AiFailure(AiFailureKind.blocked);
    }
    final candidates = decoded['candidates'];
    if (candidates == null || (candidates is List && candidates.isEmpty)) {
      throw const AiFailure(AiFailureKind.emptyResponse);
    }
    if (candidates is! List || candidates.first is! Map<String, Object?>) {
      throw const AiFailure(AiFailureKind.invalidResponse);
    }
    final candidate = candidates.first as Map<String, Object?>;
    final finishReason = candidate['finishReason'];
    if (const {
      'SAFETY',
      'RECITATION',
      'BLOCKLIST',
      'PROHIBITED_CONTENT',
      'IMAGE_SAFETY',
      'SPII',
    }.contains(finishReason)) {
      throw const AiFailure(AiFailureKind.blocked);
    }
    // Rejeita truncamentos mesmo se um fragmento parecer JSON válido.
    if (finishReason != 'STOP') {
      throw const AiFailure(AiFailureKind.invalidResponse);
    }
    final content = candidate['content'];
    if (content is! Map || content['parts'] is! List) {
      throw const AiFailure(AiFailureKind.invalidResponse);
    }
    final text = StringBuffer();
    for (final part in content['parts'] as List) {
      if (part is! Map || (part['text'] != null && part['text'] is! String)) {
        throw const AiFailure(AiFailureKind.invalidResponse);
      }
      if (part['thought'] != true && part['text'] is String) {
        text.write(part['text']);
      }
    }
    if (text.toString().trim().isEmpty) {
      throw const AiFailure(AiFailureKind.emptyResponse);
    }
    final result = jsonDecode(text.toString());
    if (result is! Map<String, Object?>) {
      throw const AiFailure(AiFailureKind.invalidResponse);
    }
    return result;
  }
}
