import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/config/env.dart';
import 'package:o_que_comer_app/data/repositories/api_catalog_repository.dart';
import 'package:o_que_comer_app/data/repositories/catalog_repository.dart';
import 'package:o_que_comer_app/data/services/api/api_client.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';
import 'package:o_que_comer_app/data/services/errors/http_error_reporter.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _Reporter implements ErrorReporter {
  final errors = <Object>[];
  bool unavailable = false;

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (unavailable) throw StateError('Destino indisponível');
    errors.add(error);
  }
}

Map<String, Object?> _recipe({
  int id = 1,
  String ingredients = '2 ovos, sal',
}) => {
  'id': id,
  'receita': 'Omelete',
  'ingredientes': ingredients,
  'modo_preparo': '1. Bata os ovos. 2. Cozinhe por 3 minutos.',
  'link_imagem': 'https://example.com/omelete.jpg',
  'tipo': 'salgado',
  'created_at': '2024-08-11T22:02:58.854Z',
  'IngredientesBase': [
    {
      'id': id,
      'nomesIngrediente': ['ovos', 'sal'],
      'receita_id': id,
    },
  ],
};

Map<String, Object?> _page(
  List<Object?> items, {
  int page = 1,
  int limit = 20,
  int? total,
}) => {
  'items': items,
  'meta': {
    'currentPage': page,
    'itemsPerPage': limit,
    'itemCount': items.length,
    'totalItems': total ?? items.length,
    'totalPages': ((total ?? items.length) / limit).ceil(),
  },
};

ResponseBody _response(Object? body, {int status = 200}) =>
    _raw(jsonEncode(body), status: status);

ResponseBody _raw(String body, {int status = 200}) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  late _Reporter reporter;
  late _Adapter adapter;

  CatalogRepository build(
    Future<ResponseBody> Function(RequestOptions) handler,
  ) {
    adapter = _Adapter(handler);
    final client = CatalogApiClient(
      const Env(
        catalogBaseUrl: 'https://catalog.test',
        geminiBaseUrl: '',
        geminiApiKey: '',
      ),
      HttpErrorReporter(errorReporter: reporter),
      httpClientAdapter: adapter,
      enableLogs: false,
    );
    addTearDown(client.close);
    return ApiCatalogRepository(client: client, errorReporter: reporter);
  }

  setUp(() => reporter = _Reporter());

  test(
    'carrega todas as páginas para a busca local sem omitir resultados',
    () async {
      final repository = build((options) async {
        if (options.queryParameters['page'] == 1) {
          return _response(
            _page(
              List.generate(100, (i) => _recipe(id: i + 1)),
              limit: 100,
              total: 101,
            ),
          );
        }
        return _response(
          _page([_recipe(id: 101)], page: 2, limit: 100, total: 101),
        );
      });
      final recipes = await repository.getAllRecipes();
      expect(recipes, hasLength(101));
      expect(recipes.last.id, '101');
      expect(
        adapter.requests.map((request) => request.queryParameters['page']),
        [1, 2],
      );
      expect(() => recipes.clear(), throwsUnsupportedError);
    },
  );

  test('catálogo completo sem receitas retorna lista vazia', () async {
    final repository = build((_) async => _response(_page([], limit: 100)));
    expect(await repository.getAllRecipes(), isEmpty);
    expect(reporter.errors, isEmpty);
  });

  test(
    'falha em página posterior não apresenta um catálogo incompleto',
    () async {
      final repository = build((options) async {
        if (options.queryParameters['page'] == 2) {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          );
        }
        return _response(
          _page(
            List.generate(100, (i) => _recipe(id: i + 1)),
            limit: 100,
            total: 101,
          ),
        );
      });
      await expectLater(
        repository.getAllRecipes(),
        throwsA(isA<NoConnectionFailure>()),
      );
      expect(reporter.errors, isEmpty);
    },
  );

  test(
    'descobre categorias distintas inclusive após a primeira página',
    () async {
      final repository = build((options) async {
        if (options.queryParameters['page'] == 1) {
          return _response(
            _page(
              List.generate(100, (index) => _recipe(id: index + 1)),
              limit: 100,
              total: 102,
            ),
          );
        }
        return _response(
          _page(
            [
              {..._recipe(id: 101), 'tipo': 'doce'},
              {..._recipe(id: 102), 'tipo': 'agridoce'},
            ],
            page: 2,
            limit: 100,
            total: 102,
          ),
        );
      });
      final categories = await repository.getCategories();
      expect(categories.map((item) => item.id), [
        'salgado',
        'doce',
        'agridoce',
      ]);
      expect(adapter.requests.map((item) => item.queryParameters['page']), [
        1,
        2,
      ]);
    },
  );

  test('catálogo vazio retorna categorias vazias', () async {
    final repository = build((_) async => _response(_page([], limit: 100)));
    expect(await repository.getCategories(), isEmpty);
    expect(reporter.errors, isEmpty);
  });

  test(
    'tipo retornado pelo catálogo não depende de lista fixa no app',
    () async {
      final repository = build(
        (_) async => _response(
          _page([
            {..._recipe(), 'tipo': 'nova categoria'},
          ], limit: 100),
        ),
      );
      expect((await repository.getCategories()).single.label, 'Nova categoria');
    },
  );

  test('categoria ausente é erro de contrato, sem ocultar receitas', () async {
    final repository = build(
      (_) async => _response(
        _page([
          {..._recipe(), 'tipo': null},
        ], limit: 100),
      ),
    );
    await expectLater(
      repository.getCategories(),
      throwsA(isA<InvalidResponseFailure>()),
    );
    expect(reporter.errors, hasLength(1));
  });

  test('consulta categoria pela rota pública e converte os dados', () async {
    final repository = build(
      (_) async => _response([
        {..._recipe(), 'tipo': 'doce'},
      ]),
    );
    final recipes = await repository.getRecipesByCategory(' Doce ');
    expect(adapter.requests.single.path, '/receitas/tipo/doce');
    expect(recipes.single.type, 'doce');
    expect(recipes.single.preparationMinutes, isNull);
  });

  test('categoria sem receitas retorna lista vazia', () async {
    final repository = build((_) async => _response([]));
    expect(await repository.getRecipesByCategory('doce'), isEmpty);
    expect(reporter.errors, isEmpty);
  });

  test(
    'não apresenta receitas de outra categoria como resultado válido',
    () async {
      final repository = build((_) async => _response([_recipe()]));
      await expectLater(
        repository.getRecipesByCategory('doce'),
        throwsA(isA<InvalidResponseFailure>()),
      );
      expect(reporter.errors, hasLength(1));
    },
  );

  test('categoria com envelope inválido produz erro de domínio', () async {
    final repository = build((_) async => _response({'items': []}));
    await expectLater(
      repository.getRecipesByCategory('doce'),
      throwsA(isA<InvalidResponseFailure>()),
    );
  });

  test(
    'lista pelo cliente HTTP configurado e converte o modelo compartilhado',
    () async {
      final repository = build((_) async => _response(_page([_recipe()])));
      final recipes = await repository.listRecipes();

      expect(recipes, hasLength(1));
      final recipe = recipes.single;
      expect(recipe.id, '1');
      expect(recipe.title, 'Omelete');
      expect(recipe.source, RecipeSource.catalog);
      expect(recipe.baseIngredients, ['ovos', 'sal']);
      expect(recipe.imageUrl, 'https://example.com/omelete.jpg');
      expect(recipe.type, 'salgado');
      expect(recipe.createdAt, DateTime.utc(2024, 8, 11, 22, 2, 58, 854));
      // A mesma serialização utilizada ao favoritar uma receita de IA.
      expect(Recipe.fromJson(recipe.toJson()), recipe);
      expect(adapter.requests.single.uri.host, 'catalog.test');
      expect(adapter.requests.single.path, '/receitas/todas');
      expect(adapter.requests.single.queryParameters, {'page': 1, 'limit': 20});
      expect(reporter.errors, isEmpty);
      expect(() => recipes.clear(), throwsUnsupportedError);
    },
  );

  test('listagem aceita uma página além do fim como lista vazia', () async {
    final repository = build((_) async => _response(_page([], page: 2)));
    expect(await repository.listRecipes(page: 2), isEmpty);
    expect(reporter.errors, isEmpty);
  });

  test('busca por nome usa descricao e preserva caracteres na query', () async {
    const query = 'pão & queijo/ovo?';
    final repository = build(
      (_) async => _response(_page([_recipe()], page: 2, limit: 10, total: 11)),
    );
    final recipes = await repository.searchByName(
      ' $query ',
      page: 2,
      limit: 10,
    );

    expect(recipes.single.id, '1');
    final request = adapter.requests.single;
    expect(request.path, '/receitas/descricao');
    expect(request.uri.queryParameters, {
      'descricao': query,
      'page': '2',
      'limit': '10',
    });
  });

  test('busca sem resultados é uma lista vazia sem reporte de erro', () async {
    final repository = build((_) async => _response(_page([])));
    expect(await repository.searchByName('inexistente'), isEmpty);
    expect(reporter.errors, isEmpty);
  });

  test('buscas em branco não enviam requisições', () async {
    final repository = build(
      (_) async => throw StateError('Não deveria chamar'),
    );
    expect(await repository.searchByName('  '), isEmpty);
    expect(await repository.searchByIngredient('  '), isEmpty);
    expect(adapter.requests, isEmpty);
    expect(reporter.errors, isEmpty);
  });

  test(
    'detalhe preserva ingredientes, preparo e quantidades decimais',
    () async {
      const ingredients = '1,5 xícara de farinha, 2 ovos';
      final repository = build(
        (_) async => _response(_recipe(ingredients: ingredients)),
      );
      final recipe = await repository.getRecipe('1');

      expect(adapter.requests.single.path, '/receitas/1');
      expect(recipe.ingredients, [ingredients]);
      expect(recipe.steps, ['1. Bata os ovos. 2. Cozinhe por 3 minutos.']);
      expect(recipe.favoritedAt, isNull);
    },
  );

  test(
    'busca por ingrediente usa texto e os nomes base, sem diferenciar acentos',
    () async {
      final repository = build(
        (_) async => _response(
          _page([
            {
              ..._recipe(id: 1),
              'ingredientes': 'Açúcar mascavo',
              'IngredientesBase': [],
            },
            {
              ..._recipe(id: 2),
              'IngredientesBase': [
                {
                  'nomesIngrediente': ['açúcar'],
                },
              ],
            },
            {..._recipe(id: 3), 'receita': 'Açúcar no título apenas'},
          ], limit: 100),
        ),
      );
      final recipes = await repository.searchByIngredient(' ACUCAR ');
      expect(recipes.map((item) => item.id), ['1', '2']);
      expect(adapter.requests.single.path, '/receitas/todas');
      expect(adapter.requests.single.queryParameters['limit'], 100);
    },
  );

  test('busca por ingrediente consulta páginas seguintes até o fim', () async {
    final repository = build((options) async {
      final page = options.queryParameters['page'];
      return _response(
        page == 1
            ? _page(
                List.generate(100, (i) => _recipe(id: i + 1)),
                limit: 100,
                total: 101,
              )
            : _page(
                [_recipe(id: 101, ingredients: 'Arroz integral')],
                page: 2,
                limit: 100,
                total: 101,
              ),
      );
    });
    final recipes = await repository.searchByIngredient('arroz');

    expect(recipes.single.id, '101');
    expect(adapter.requests.map((r) => r.queryParameters['page']), [1, 2]);
  });

  test(
    'busca por ingrediente sem correspondência retorna lista vazia',
    () async {
      final repository = build(
        (_) async => _response(_page([_recipe()], limit: 100)),
      );
      expect(await repository.searchByIngredient('abacaxi'), isEmpty);
      expect(reporter.errors, isEmpty);
    },
  );

  test(
    'falha em página posterior não devolve uma busca parcial como sucesso',
    () async {
      final repository = build((options) async {
        if (options.queryParameters['page'] == 2) {
          throw DioException.connectionError(
            requestOptions: options,
            reason: 'offline',
          );
        }
        return _response(
          _page(
            List.generate(100, (i) => _recipe(id: i + 1)),
            limit: 100,
            total: 101,
          ),
        );
      });
      await expectLater(
        repository.searchByIngredient('ovos'),
        throwsA(isA<NoConnectionFailure>()),
      );
      expect(adapter.requests, hasLength(2));
      expect(reporter.errors, isEmpty);
    },
  );

  final operations = <String, Future<Object> Function(CatalogRepository)>{
    'catálogo completo': (repository) => repository.getAllRecipes(),
    'categorias': (repository) => repository.getCategories(),
    'receitas da categoria': (repository) =>
        repository.getRecipesByCategory('doce'),
    'listar': (repository) => repository.listRecipes(),
    'buscar nome': (repository) => repository.searchByName('bolo'),
    'buscar ingrediente': (repository) => repository.searchByIngredient('ovos'),
    'detalhar': (repository) => repository.getRecipe('1'),
  };
  for (final operation in operations.entries) {
    test('${operation.key}: conexão perdida é erro de domínio', () async {
      final repository = build(
        (options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );
      await expectLater(
        operation.value(repository),
        throwsA(isA<NoConnectionFailure>()),
      );
      expect(reporter.errors, isEmpty);
    });
  }

  test('timeout é distinto de falta de conexão', () async {
    final repository = build(
      (options) async => throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 20),
        requestOptions: options,
      ),
    );
    await expectLater(repository.listRecipes(), throwsA(isA<TimeoutFailure>()));
    expect(reporter.errors, isEmpty);
  });

  for (final status in [404, 429, 503]) {
    test('HTTP $status preserva o erro de domínio do cliente', () async {
      final repository = build((_) async => _response({}, status: status));
      await expectLater(
        repository.getRecipe('1'),
        throwsA(
          status < 500
              ? isA<ClientFailure>().having(
                  (f) => f.statusCode,
                  'status',
                  status,
                )
              : isA<ServerFailure>().having(
                  (f) => f.statusCode,
                  'status',
                  status,
                ),
        ),
      );
      expect(reporter.errors, isEmpty);
    });
  }

  final invalidBodies = <String, String>{
    'corpo vazio': '',
    'null': 'null',
    'JSON truncado': '{"items":',
    'envelope incorreto': '{"data":[]}',
    'lista sem envelope': '[]',
    'HTML': '<html>Falha no servidor</html>',
    'item inválido': jsonEncode(
      _page([
        {'id': 1, 'receita': 'Item incompleto'},
      ]),
    ),
    'metadados incoerentes': jsonEncode({
      ..._page([_recipe()]),
      'meta': {...(_page([])['meta']! as Map<String, Object?>), 'itemCount': 9},
    }),
  };
  for (final body in invalidBodies.entries) {
    test(
      '${body.key}: retorna InvalidResponseFailure e reporta uma vez',
      () async {
        final repository = build((_) async => _raw(body.value));
        await expectLater(
          repository.listRecipes(),
          throwsA(isA<InvalidResponseFailure>()),
        );
        expect(reporter.errors, hasLength(1));
        expect(reporter.errors.single, isA<CatalogIntegrationError>());
        expect(
          reporter.errors.single.toString(),
          isNot(
            contains(body.value.isEmpty ? 'Resposta sem corpo' : body.value),
          ),
        );
      },
    );
  }

  test('receita inexistente (200 sem corpo) vira não encontrada', () async {
    final repository = build((_) async => _response(null));
    await expectLater(
      repository.getRecipe('999999999'),
      throwsA(
        isA<ClientFailure>().having((f) => f.isNotFound, 'isNotFound', true),
      ),
    );
    // Receita inexistente é um caso normal: não vai para o Crashlytics.
    expect(reporter.errors, isEmpty);
  });

  test('detalhe não aceita o ID de outra receita', () async {
    final repository = build((_) async => _response(_recipe(id: 2)));
    await expectLater(
      repository.getRecipe('1'),
      throwsA(isA<InvalidResponseFailure>()),
    );
  });

  test(
    'servidor repetindo página não causa loop na busca por ingrediente',
    () async {
      final page = _page(
        List.generate(100, (i) => _recipe(id: i + 1)),
        limit: 100,
        total: 101,
      );
      final repository = build((_) async => _response(page));
      await expectLater(
        repository.searchByIngredient('ovos'),
        throwsA(isA<InvalidResponseFailure>()),
      );
      expect(adapter.requests, hasLength(2));
    },
  );

  test('entrada inválida é rejeitada antes do HTTP sem reporte', () async {
    final repository = build(
      (_) async => throw StateError('Não deveria chamar'),
    );
    await expectLater(
      repository.listRecipes(page: 0),
      throwsA(isA<InvalidInputFailure>()),
    );
    await expectLater(
      repository.searchByName('bolo', limit: 101),
      throwsA(isA<InvalidInputFailure>()),
    );
    await expectLater(
      repository.getRecipe('../todas'),
      throwsA(isA<InvalidInputFailure>()),
    );
    expect(adapter.requests, isEmpty);
    expect(reporter.errors, isEmpty);
  });

  test(
    'indisponibilidade do Crashlytics não substitui a resposta inválida',
    () async {
      reporter.unavailable = true;
      final repository = build((_) async => _response({'payload': 'inválido'}));
      await expectLater(
        repository.listRecipes(),
        throwsA(isA<InvalidResponseFailure>()),
      );
    },
  );

  test(
    'erro inesperado do HTTP é reportado uma vez e vira falha de domínio',
    () async {
      final repository = build((_) async => throw StateError('boom'));
      await expectLater(
        repository.listRecipes(),
        throwsA(isA<UnexpectedFailure>()),
      );
      expect(reporter.errors, hasLength(1));
    },
  );
}
