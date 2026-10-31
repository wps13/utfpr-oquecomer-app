# Filtrar receitas por nome — APP-26 / US02

A aba **Buscar** apresenta um campo para digitar o nome da receita e usa a mesma
`RecipeList` e os mesmos cards da listagem por categoria da APP-25.

## Comportamento

- Ao abrir a tela, o app consulta o catálogo completo e mostra a listagem original.
- O texto filtra receitas cujo **nome contém** o trecho digitado. Ingredientes e
  modo de preparo não participam da comparação.
- A comparação ignora caixa e acentos comuns em português, incluindo acentos
  Unicode decompostos. Por exemplo, `LIMAO`, `limão` e `limão` encontram
  `Torta de Limão`.
- O resultado muda durante a digitação, sem necessidade de enviar o campo.
- Sem correspondências, aparece **Nenhuma receita encontrada**.
- Apagar o texto ou tocar no botão **Limpar busca** restaura a lista original,
  preservando sua ordem e sem outra consulta HTTP.
- Abrir uma receita usa a rota de detalhe existente. Voltar preserva o texto
  digitado e os resultados.
- Carregamento e erro são explícitos; **Tentar novamente** repete a consulta
  preservando o texto. O texto digitado antes do fim da carga também é aplicado.

## Consulta e normalização

`CatalogRepository.getAllRecipes()` consulta `/receitas/todas` em páginas de até
100 itens e somente devolve o catálogo quando todas as páginas terminam. Assim,
receitas de páginas seguintes também podem ser encontradas, e uma falha não
produz resultados parciais apresentados como completos.

A busca é feita sobre esse catálogo durante a vida da tela. A API pública tem
um endpoint de busca por descrição/nome, mas seu comportamento não garante a
normalização exigida pelo card: na conferência de 30/10/2026, `limão` retornou
resultados enquanto `limao` e `LIMÃO` não retornaram. Por isso, a interface não
depende desse endpoint para filtrar texto.

`SearchViewModel` recebe o repositório pelo construtor e aplica
`normalizeRecipeName()` ao título e à consulta. Os dados mantêm seus nomes
originais para exibição. A carga não é repetida a cada tecla e nenhum termo de
busca é enviado ao servidor. Não há persistência de catálogo ou de buscas;
reabrir a tela consulta novamente a API.

O router cria a ViewModel com Provider. O controlador de texto e o foco pertencem
ao widget e são descartados com a tela. Respostas antigas não substituem uma
carga mais recente, e sair da tela durante uma consulta não gera notificação
após o descarte da ViewModel.

Não foram adicionados busca por ingredientes, sugestões, histórico ou busca por
voz. A API continua sendo a fonte dos dados; não há backend novo.

## Como validar

```sh
flutter test test/utils/recipe_name_search_test.dart \
  test/ui/search \
  test/data/repositories/api_catalog_repository_test.dart \
  test/routing/router_test.dart
flutter test
flutter analyze --fatal-infos --fatal-warnings
```

Para validar a carga real e o filtro normalizado com a API pública, sem emulador
ou credenciais:

```sh
flutter test tool/catalog_smoke_test.dart
```

Para executar o app:

```sh
flutter run \
  --dart-define-from-file=config/firebase.local.json \
  --dart-define-from-file=config/gemini.local.json
```

1. Abra **Buscar** e confira a lista original.
2. Digite `LIMAO` e confira receitas como `Torta de Limão`. Repita com `limão`.
3. Digite um texto sem correspondências e confira a mensagem de lista vazia.
4. Use **Limpar busca** e confira o retorno da listagem original.
5. Busque novamente, abra uma receita e volte para conferir o texto e o filtro.

A APP-26 foi iniciada sobre a APP-25 para reutilizar sua interface. Se o PR da
APP-25 ainda estiver aberto, a revisão da APP-26 pode usar `feat/APP-25` como
base; após a integração da APP-25, a base deve ser atualizada para `develop`.
