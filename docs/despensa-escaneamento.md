# Despensa: alimentos escaneados

Ao enviar a foto para criar uma receita, os alimentos detectados são guardados
localmente como itens da despensa, com nome e data do escaneamento. Eles
alimentam o histórico da despensa inteligente. A imagem original, a quantidade
e a validade dos alimentos não são guardadas.

## Componentes

- `PantryItem` (`lib/domain/models/pantry_item.dart`): `name` (grafia original,
  para exibir), `scannedAt` e `id`, o nome normalizado.
- `PantryRepository` (`lib/data/repositories/pantry_repository.dart`): interface
  injetada nas ViewModels, com `saveScanned(foods)` e `getItems()`.
- `LocalPantryRepository` implementa a interface sobre uma `PantryBox`:
  `HivePantryBox` (box `pantry`, usada pelo app) ou `InMemoryPantryBox` (sem
  persistência, usada quando o armazenamento local não abre).
- `AiRecipesViewModel` chama `saveScanned` logo depois que o escaneamento
  detecta os alimentos.

## Quando os itens são guardados

- Só depois de um escaneamento bem-sucedido, com pelo menos um alimento. Se o
  escaneamento falhar, ou não detectar nada, nada é guardado.
- Todos os alimentos detectados são guardados, mesmo que o usuário remova algum
  da lista antes de gerar a receita. Gerar a receita não guarda de novo; enviar
  outra foto, sim.
- Os alimentos de um mesmo escaneamento recebem a mesma data (UTC).
- Uma falha ao gravar não impede de seguir para a receita. O repositório
  reporta o erro (`PantryStorageError`) ao Crashlytics e a ViewModel continua.

## Sem duplicados

O registro de cada item usa o `id` como chave no Hive, então guardar o mesmo
alimento outra vez sobrescreve o registro, sem leitura prévia e sem corrida entre
gravações simultâneas. O `id` é o nome sem acentos, em minúsculas e com os
espaços repetidos juntados: "Pimentão  Verde " e "pimentao verde" são o mesmo
alimento.

Quando o alimento já existe, o item mantém o nome da primeira vez e recebe a
data do escaneamento mais recente.

Limites conhecidos: plural e sinônimos não são tratados ("tomate" e "tomates",
"mandioca" e "aipim" são itens diferentes). Mudar a regra de normalização exige
recalcular as chaves a partir do nome guardado.

## Formato local

O box `pantry` tem uma entrada por alimento, com a chave igual ao `id`:

```json
{ "nome": "Pimentão Verde", "escaneado_em": "2026-05-01T12:00:00.000Z" }
```

Os itens continuam disponíveis depois de reiniciar o app. `getItems()` os devolve
do escaneamento mais recente para o mais antigo. Um registro ilegível ao listar
é reportado e propagado; ao escanear o mesmo alimento, ele é sobrescrito.

## Testes

- `test/domain/models/pantry_item_test.dart`: normalização e JSON.
- `test/data/repositories/pantry_repository_test.dart`: gravação, duplicados,
  data, ordem, persistência ao reabrir o box e falhas, com Hive de teste.
- `test/ui/ai_recipes/view_models/ai_recipes_viewmodel_test.dart`: quando a
  ViewModel guarda, e que uma falha do escaneamento ou da gravação se comporta
  como descrito acima. ViewModels usam `FakePantryRepository`, de
  `testing/fakes/`.
