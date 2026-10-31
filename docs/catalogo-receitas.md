# Catálogo de receitas — APP-24 / TT12

O catálogo usa a API pública [DenilsonRabelo/API-Receitas](https://github.com/DenilsonRabelo/API-Receitas),
através do `CatalogApiClient` (Dio) já existente. As consultas utilizadas são
públicas e não exigem chave nem autenticação.

## Configuração

A URL padrão é `https://api-receitas-pi.vercel.app`. Os comandos de execução
do [README](../README.md#executar-localmente) continuam funcionando sem arquivo
adicional para o catálogo. Para usar outra instância, acrescente:

```sh
flutter run \
  --dart-define-from-file=config/firebase.local.json \
  --dart-define-from-file=config/gemini.local.json \
  --dart-define=CATALOG_BASE_URL=https://api-receitas-pi.vercel.app
```

Também é possível definir `CATALOG_BASE_URL` no `env.json` local, conforme
`env.example.json`. A URL deve apontar à raiz, sem o sufixo `/receitas`.
O cliente mantém os limites de conexão de 10 segundos e resposta de 20 segundos.

## Contrato e rotas

O contrato foi conferido no código público da API
([controller](https://github.com/DenilsonRabelo/API-Receitas/blob/be7b56e48d6f297914518d04ea92101234dc4ce4/src/receitas/receita.controller.ts)
e [service](https://github.com/DenilsonRabelo/API-Receitas/blob/be7b56e48d6f297914518d04ea92101234dc4ce4/src/receitas/receita.service.ts))
e em respostas reais em 24/10/2026. Há diferenças em relação aos exemplos do
README externo: as listagens retornam `items` e metadados com `currentPage`,
`totalPages`, `totalItems`, `itemsPerPage` e `itemCount`.

| Operação do repositório | Requisição |
| --- | --- |
| `listRecipes(page: 1, limit: 20)` | `GET /receitas/todas?page=1&limit=20` |
| `searchByName('bolo')` | `GET /receitas/descricao?descricao=bolo&page=1&limit=20` |
| `getRecipe('1')` | `GET /receitas/1` |
| `searchByIngredient('cenoura')` | Consulta `/receitas/todas` em páginas de até 100 e filtra no repositório |

A rota `descricao` pesquisa somente o nome. Não há endpoint público que busque
receitas pelo ingrediente; `/receitas/ingredientes/:id` retorna um registro de
ingredientes base e não substitui essa busca. Por isso, `searchByIngredient`
consulta as páginas sequencialmente e compara o termo com `ingredientes` e
`IngredientesBase[].nomesIngrediente`, ignorando maiúsculas e acentos comuns
do português. A comparação é por trecho, sem análise de sinônimos ou plurais.

A busca percorre todo o catálogo para não omitir receitas nas páginas seguintes.
Não mantém cache: seu custo cresce com o catálogo. Se uma página falhar, a
operação retorna a falha, sem apresentar resultados parciais como completos.
O código valida a página recebida para impedir loops caso o servidor ignore
o parâmetro. Não há filtros extras nem navegação de paginação na interface.

As buscas em branco retornam lista vazia sem chamada HTTP. Uma resposta válida
com `items: []` também é sucesso, sem reporte ao Crashlytics. A listagem e a
busca por nome aceitam página positiva e limite entre 1 e 100.

## DTOs e modelo compartilhado

`CatalogRecipeDto` e `CatalogPageDto`, em
`lib/data/model/catalog_recipe_dto.dart`, validam o contrato externo.
`toRecipe()` produz o mesmo `Recipe` da IA e dos favoritos:

- ID numérico da API convertido para `String` e `source: RecipeSource.catalog`.
- `receita` vira `title`.
- `ingredientes` e `modo_preparo` são preservados integralmente em um elemento
  das listas `ingredients` e `steps`. Isso evita corromper números decimais,
  quantidades e instruções ao tentar adivinhar separadores.
- `IngredientesBase[].nomesIngrediente` é convertido para `baseIngredients`.
- `link_imagem`, `tipo` e `created_at` alimentam os campos opcionais do modelo.
- A API não fornece duração nem rendimento. O DTO mantém os valores padrão
  atuais do modelo (`preparationMinutes: 1`, `servings: 1`); esses valores não
  representam informações confirmadas pelo catálogo.

A serialização usada na persistência dos favoritos permanece a mesma. Consultar
uma receita não a salva automaticamente.

## Injeção

O `main.dart` registra `CatalogRepository` acima do `MaterialApp` e fecha o
cliente HTTP ao descartar seu Provider. As ViewModels devem receber a interface
pelo construtor, por exemplo:

```dart
CatalogViewModel(repository: context.read<CatalogRepository>())
```

`CatalogViewModel` é apenas um exemplo de composição; as telas e ViewModels
de catálogo, busca e detalhe ficam para os respectivos cards. A implementação
disponível é `ApiCatalogRepository`.

## Falhas de domínio e telemetria

| Falha | Situação |
| --- | --- |
| `NoConnectionFailure` | Sem conexão ou servidor inalcançável |
| `TimeoutFailure` | Conexão, envio ou resposta excedem o tempo limite |
| `InvalidResponseFailure` | Corpo vazio, JSON inválido, campos ausentes ou incompatíveis, paginação incoerente |
| `InvalidInputFailure` | ID inválido ou parâmetros de paginação fora do intervalo |
| `ClientFailure` | HTTP 4xx, incluindo 404 e 429 |
| `ServerFailure` | HTTP 5xx |
| `CancelledFailure` | Requisição cancelada |
| `UnexpectedFailure` | Outra falha não prevista |

Atualmente a API responde com corpo vazio/nulo e HTTP 200 para alguns IDs
inexistentes; esse caso gera `InvalidResponseFailure`. Um HTTP 404 é preservado
como `ClientFailure` com `isNotFound`.

Respostas incompatíveis e falhas não previstas são encaminhadas ao
`ErrorReporter`. Erros de parsing usam `CatalogIntegrationError`, contendo
somente operação e tipo de erro, sem o corpo da resposta nem a busca.
Falhas de transporte inesperadas já reportadas pelo cliente não são reportadas
novamente pelo repositório. Falhas do próprio reporter não interrompem o retorno
do erro de domínio. A política do Crashlytics continua habilitando o envio
somente em release, conforme o APP-19.

## Validação

Os testes simulam respostas através do adaptador do Dio, exercitando o cliente
configurado, DTOs e repositório sem internet nem credenciais:

```sh
flutter test test/data/model/catalog_recipe_dto_test.dart \
  test/data/repositories/api_catalog_repository_test.dart
flutter test
flutter analyze --fatal-infos --fatal-warnings
```

Para verificar manualmente a API pública, fora da suíte padrão:

```sh
flutter test tool/catalog_smoke_test.dart
```

Esse teste consulta listagem, detalhe, busca por nome, busca por ingrediente e
busca sem resultado. Exige internet e disponibilidade da API; não precisa de
Firebase, Gemini, emulador ou celular. Nenhuma rota de escrita é utilizada.
