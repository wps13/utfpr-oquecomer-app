import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:o_que_comer_app/config/ai_dependencies.dart';
import 'package:o_que_comer_app/config/gemini_config.dart';
import 'package:o_que_comer_app/data/repositories/gemini_ai_repository.dart';
import 'package:o_que_comer_app/data/services/ai/gemini_service.dart';
import 'package:o_que_comer_app/data/services/api/json_api_client.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';
import 'package:o_que_comer_app/domain/models/ai_failure.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';

const recipeJson = <String, Object?>{
  'title': 'Omelete de tomate',
  'description': 'Uma refeição simples e rápida.',
  'ingredients': ['2 ovos', '1 tomate', '1 pitada de sal'],
  'steps': ['Bata os ovos.', 'Junte o tomate e cozinhe na frigideira.'],
  'preparationMinutes': 15,
  'servings': 2,
};

http.Response envelope(Object? payload, {String finishReason = 'STOP'}) =>
    http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'candidates': [
            {
              'finishReason': finishReason,
              'content': {
                'parts': [
                  {'text': jsonEncode(payload)},
                ],
              },
            },
          ],
        }),
      ),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Matcher failure(AiFailureKind kind) =>
    isA<AiFailure>().having((value) => value.kind, 'kind', kind);

class RecordingReporter implements ErrorReporter {
  final errors = <Object>[];
  final stacks = <StackTrace>[];
  final fatalFlags = <bool>[];
  bool shouldFail = false;

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    errors.add(error);
    stacks.add(stackTrace);
    fatalFlags.add(fatal);
    if (shouldFail) throw StateError('Telemetria indisponível.');
  }
}

void main() {
  late RecordingReporter reporter;
  late http.Client client;
  late GeminiAiRepository repository;
  late int requests;

  void configure(
    Future<http.Response> Function(http.Request) handler, {
    GeminiConfig config = const GeminiConfig(apiKey: 'test-key'),
  }) {
    client = MockClient((request) {
      requests++;
      return handler(request);
    });
    repository = GeminiAiRepository(
      service: GeminiService(
        apiClient: JsonApiClient(client: client),
        config: config,
      ),
      errorReporter: reporter,
      createRecipeId: () => 'ai_test',
    );
  }

  setUp(() {
    reporter = RecordingReporter();
    requests = 0;
    configure((_) async => envelope(recipeJson));
  });
  tearDown(() => client.close());

  test(
    'gera receita em português no modelo compartilhado, sem persistir',
    () async {
      final recipe = await repository.generateRecipe(['ovos', 'tomate']);

      expect(recipe.id, 'ai_test');
      expect(recipe.source, RecipeSource.ai);
      expect(recipe.title, 'Omelete de tomate');
      expect(recipe.ingredients, ['2 ovos', '1 tomate', '1 pitada de sal']);
      expect(recipe.steps, hasLength(2));
      expect(recipe.preparationMinutes, 15);
      expect(recipe.servings, 2);
      expect(Recipe.fromJson(recipe.toJson()).toJson(), recipe.toJson());
      expect(() => recipe.ingredients.add('outro'), throwsUnsupportedError);
      expect(reporter.errors, isEmpty);
    },
  );

  test(
    'envia chave no header, parâmetros e contrato JSON em português',
    () async {
      configure(
        (request) async {
          expect(request.method, 'POST');
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'generativelanguage.googleapis.com');
          expect(
            request.url.path,
            '/v1beta/models/gemini-test:generateContent',
          );
          expect(request.url.query, isEmpty);
          expect(request.headers['x-goog-api-key'], 'test-key');
          expect(request.headers['content-type'], contains('application/json'));
          expect(request.body, isNot(contains('test-key')));
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['systemInstruction'].toString(), contains('português'));
          final contents = body['contents'] as List<dynamic>;
          expect(contents, hasLength(1));
          final content = contents.single as Map<String, dynamic>;
          final parts = content['parts'] as List<dynamic>;
          expect(parts, hasLength(1));
          expect(parts.single.toString(), contains('["ovos","tomate"]'));
          final config = body['generationConfig'] as Map<String, dynamic>;
          expect(config['temperature'], 0.2);
          expect(config['maxOutputTokens'], 2048);
          expect(config['candidateCount'], 1);
          final format = config['responseFormat'] as Map<String, dynamic>;
          final text = format['text'] as Map<String, dynamic>;
          expect(text['mimeType'], 'APPLICATION_JSON');
          final schema = text['schema'] as Map<String, dynamic>;
          expect(
            schema['required'],
            containsAll(['title', 'steps', 'servings']),
          );
          return envelope({
            ...recipeJson,
            'id': 'catalog_id',
            'source': 'catalog',
          });
        },
        config: const GeminiConfig(
          apiKey: 'test-key',
          model: 'gemini-test',
          temperature: 0.2,
          maxOutputTokens: 2048,
        ),
      );

      expect(requests, 0);
      final recipe = await repository.generateRecipe([
        ' ovos ',
        'OVOS',
        'tomate',
      ]);
      expect(recipe.id, 'ai_test');
      expect(recipe.source, RecipeSource.ai);
      expect(requests, 1);
    },
  );

  test(
    'identifica alimentos e envia bytes e MIME da foto sem ler arquivos',
    () async {
      final bytes = Uint8List.fromList([255, 216, 255, 217]);
      configure((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final contents = body['contents'] as List<dynamic>;
        final content = contents.single as Map<String, dynamic>;
        final parts = content['parts'] as List<dynamic>;
        final imagePart = parts.last as Map<String, dynamic>;
        final image = imagePart['inlineData'] as Map<String, dynamic>;
        expect(image['mimeType'], 'image/jpeg');
        expect(base64Decode(image['data'] as String), bytes);
        return envelope({
          'foods': [' Tomate ', 'OVO', 'tomate'],
        });
      });

      final foods = await repository.identifyFoods(
        imageBytes: bytes,
        mimeType: 'image/jpeg',
      );
      expect(foods, ['Tomate', 'OVO']);
      expect(() => foods.add('outro'), throwsUnsupportedError);
      expect(reporter.errors, isEmpty);
    },
  );

  test(
    'foto sem alimentos retorna lista vazia como resultado válido',
    () async {
      configure((_) async => envelope({'foods': <String>[]}));
      expect(
        await repository.identifyFoods(
          imageBytes: Uint8List.fromList([1]),
          mimeType: 'image/png',
        ),
        isEmpty,
      );
    },
  );

  for (final invalid in <Object?>[
    null,
    [],
    {},
    {...recipeJson, 'title': ''},
    {...recipeJson, 'description': null},
    {...recipeJson, 'ingredients': []},
    {
      ...recipeJson,
      'ingredients': [42],
    },
    {
      ...recipeJson,
      'steps': [''],
    },
    {...recipeJson, 'preparationMinutes': '15'},
    {...recipeJson, 'preparationMinutes': 1.5},
    {...recipeJson, 'servings': 0},
  ].indexed) {
    test('receita inválida ${invalid.$1} retorna erro de domínio', () async {
      configure((_) async => envelope(invalid.$2));
      await expectLater(
        repository.generateRecipe(['ovos']),
        throwsA(failure(AiFailureKind.invalidResponse)),
      );
      expect(reporter.errors, isEmpty);
    });
  }

  for (final invalid in <Object?>[
    null,
    'tomate',
    [5],
    [''],
    ['tomate', null],
  ]) {
    test('lista de alimentos inválida $invalid é rejeitada', () async {
      configure((_) async => envelope({'foods': invalid}));
      await expectLater(
        repository.identifyFoods(
          imageBytes: Uint8List.fromList([1]),
          mimeType: 'image/webp',
        ),
        throwsA(failure(AiFailureKind.invalidResponse)),
      );
    });
  }

  final responses = <String, (Object?, AiFailureKind)>{
    'envelope inválido': ([], AiFailureKind.invalidResponse),
    'candidatos inválidos': (
      {'candidates': true},
      AiFailureKind.invalidResponse,
    ),
    'sem candidatos': ({'candidates': []}, AiFailureKind.emptyResponse),
    'bloqueio no prompt': (
      {
        'promptFeedback': {'blockReason': 'SAFETY'},
      },
      AiFailureKind.blocked,
    ),
    'bloqueio na saída': (
      {
        'candidates': [
          {'finishReason': 'SAFETY'},
        ],
      },
      AiFailureKind.blocked,
    ),
    'conteúdo vazio': (
      {
        'candidates': [
          {
            'finishReason': 'STOP',
            'content': {'parts': []},
          },
        ],
      },
      AiFailureKind.emptyResponse,
    ),
    'JSON interno inválido': (
      {
        'candidates': [
          {
            'finishReason': 'STOP',
            'content': {
              'parts': [
                {'text': '```json'},
              ],
            },
          },
        ],
      },
      AiFailureKind.invalidResponse,
    ),
  };
  for (final entry in responses.entries) {
    test(entry.key, () async {
      configure((_) async => http.Response(jsonEncode(entry.value.$1), 200));
      await expectLater(
        repository.generateRecipe(['ovos']),
        throwsA(failure(entry.value.$2)),
      );
    });
  }

  test('truncamento não aceita nem mesmo fragmento com JSON válido', () async {
    configure((_) async => envelope(recipeJson, finishReason: 'MAX_TOKENS'));
    await expectLater(
      repository.generateRecipe(['ovos']),
      throwsA(failure(AiFailureKind.invalidResponse)),
    );
  });

  test('ignora partes de raciocínio ao extrair o JSON de saída', () async {
    configure(
      (_) async => http.Response(
        jsonEncode({
          'candidates': [
            {
              'finishReason': 'STOP',
              'content': {
                'parts': [
                  {'thought': true, 'text': 'Raciocínio interno'},
                  {'text': jsonEncode(recipeJson)},
                ],
              },
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    expect(
      (await repository.generateRecipe(['ovos'])).title,
      'Omelete de tomate',
    );
  });

  for (final status in {
    400: AiFailureKind.configuration,
    401: AiFailureKind.configuration,
    403: AiFailureKind.configuration,
    404: AiFailureKind.configuration,
    408: AiFailureKind.timeout,
    429: AiFailureKind.quotaExceeded,
    500: AiFailureKind.unavailable,
    503: AiFailureKind.unavailable,
    504: AiFailureKind.timeout,
  }.entries) {
    test(
      'HTTP ${status.key} retorna ${status.value.name} sem vazar corpo',
      () async {
        configure((_) async => http.Response('segredo no corpo', status.key));
        await expectLater(
          repository.generateRecipe(['ovos']),
          throwsA(failure(status.value)),
        );
        expect(reporter.errors, isEmpty);
      },
    );
  }

  test('falha de conexão é distinta e não vai para a telemetria', () async {
    configure((_) async => throw http.ClientException('DNS indisponível'));
    await expectLater(
      repository.generateRecipe(['ovos']),
      throwsA(failure(AiFailureKind.connection)),
    );
    expect(reporter.errors, isEmpty);
  });

  test('timeout limita o tempo de espera real do cliente', () async {
    configure(
      (_) => Completer<http.Response>().future,
      config: const GeminiConfig(
        apiKey: 'test-key',
        timeout: Duration(milliseconds: 10),
      ),
    );
    await expectLater(
      repository.generateRecipe(['ovos']),
      throwsA(failure(AiFailureKind.timeout)),
    );
  });

  test('corpo HTTP vazio tem erro distinto de JSON inválido', () async {
    configure((_) async => http.Response('', 200));
    await expectLater(
      repository.generateRecipe(['ovos']),
      throwsA(failure(AiFailureKind.emptyResponse)),
    );
    configure((_) async => http.Response('HTML inesperado', 200));
    await expectLater(
      repository.generateRecipe(['ovos']),
      throwsA(failure(AiFailureKind.invalidResponse)),
    );
  });

  test(
    'chave ausente só falha ao usar o recurso, antes de chamar a API',
    () async {
      configure(
        (_) async => envelope(recipeJson),
        config: const GeminiConfig(apiKey: ''),
      );
      expect(requests, 0);
      await expectLater(
        repository.generateRecipe(['ovos']),
        throwsA(failure(AiFailureKind.configuration)),
      );
      expect(requests, 0);
    },
  );

  test('entradas inválidas não fazem requisição', () async {
    for (final ingredients in <List<String>>[
      [],
      [' '],
      List.filled(51, 'ovo'),
    ]) {
      await expectLater(
        repository.generateRecipe(ingredients),
        throwsA(failure(AiFailureKind.invalidInput)),
      );
    }
    for (final photo in [
      (Uint8List(0), 'image/jpeg'),
      (Uint8List.fromList([1]), 'application/pdf'),
      (Uint8List(10 * 1024 * 1024 + 1), 'image/png'),
    ]) {
      await expectLater(
        repository.identifyFoods(imageBytes: photo.$1, mimeType: photo.$2),
        throwsA(failure(AiFailureKind.invalidInput)),
      );
    }
    expect(requests, 0);
  });

  test(
    'erro inesperado é não fatal e reportado com contexto sanitizado',
    () async {
      final stack = StackTrace.current;
      configure(
        (_) async => Error.throwWithStackTrace(
          StateError('test-key e dados privados'),
          stack,
        ),
      );
      await expectLater(
        repository.generateRecipe(['ovos']),
        throwsA(failure(AiFailureKind.unexpected)),
      );
      expect(reporter.errors.single, isA<AiIntegrationError>());
      expect(reporter.errors.single.toString(), contains('generateRecipe'));
      expect(reporter.errors.single.toString(), isNot(contains('test-key')));
      expect(
        reporter.errors.single.toString(),
        isNot(contains('dados privados')),
      );
      expect(reporter.stacks.single, stack);
      expect(reporter.fatalFlags, [false]);
    },
  );

  test('falha no reporter não substitui o erro de domínio', () async {
    reporter.shouldFail = true;
    configure((_) async => http.Response('detalhes privados', 418));
    await expectLater(
      repository.generateRecipe(['ovos']),
      throwsA(failure(AiFailureKind.unexpected)),
    );
    expect(reporter.errors, hasLength(1));
  });

  test(
    'composição permite injetar repositório sem conexão no startup',
    () async {
      final dependencies = AiDependencies(
        errorReporter: reporter,
        client: client,
        config: const GeminiConfig(apiKey: 'test-key'),
      );
      expect(requests, 0);
      final one = await dependencies.repository.generateRecipe(['ovos']);
      final two = await dependencies.repository.generateRecipe(['ovos']);
      expect(one.id, startsWith('ai_'));
      expect(two.id, isNot(one.id));
      dependencies.close();
    },
  );
}
